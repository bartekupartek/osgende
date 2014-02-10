# This file is part of Osgende
# Copyright (C) 2011-2014 Sarah Hoffmann
#
# This is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
"""
A graph of a collection of line segments, representing a connected
route. Holes in the graph are closed with artifical way sections.
The graph has the notion of a main route and forks and secondary routes.
"""

from collections import defaultdict
from shapely.geometry import Point, LineString
from Queue import PriorityQueue


class RouteGraphSegment(object):
    """ An edge within a route graph.
    """

    def __init__(self, segid, geom, firstpnt, lastpnt):
        # Directional way: 0 - both, 1, forward only, -1 - backward only
        self.direction = 0
        # data from segment
        self.segid = segid
        # geometry
        self.geom = geom
        self.firstpnt = firstpnt
        self.lastpnt = lastpnt
        # graph
        self.connection = []
        # main paths
        self.forward = None
        self.backward = None # TODO unimplemented

    def reverse(self):
        """ Reverse direction of way and also switch
            forward and backward connections.
        """
        self.direction = -self.direction
        self.geom.reverse()
        tmp = self.lastpnt
        self.firstpnt = self.lastpnt
        self.lastpnt = self.firstpnt


class RouteGraphPoint(object):
    """ A node within the route graph.
        The OSM node representing this graph node is `nodeid`.
    """
    def __init__(self, nodeid, coords):
        self.subnet = -1
        self.nodeid = nodeid
        self.coords = Point(coords)
        self.edges = []
        # next nodes as ids
        self.neighbours = []

    def distance_to(self, point):
        return self.coords.distance(point)


    def __repr__(self):
        return "RouteGraphPoint(nodeid=%r,subnet=%r,edges=%r,neightbours=%r)" % (
                   self.nodeid, self.subnet, len(self.edges), self.neighbours)



class RouteGraph(object):
    """ A directed graph of a route.

        The graph needs to be built up calling add_segment()
        for each segment and then sorted with build_directed_graph().
    """

    def __init__(self):
        # the starting point
        self.first_segment = None
        # nodes and their edges 
        self.nodes = {}
        self.segments = []
        
    def add_segment(self, segment):
        """Add a new segment (of type RouteGraphSegment). 
           This can only be done during built-up of the profile.
        """
        self.segments.append(segment)
        self._add_segment_to_node(segment.firstpnt, segment.geom.coords[0], segment.lastpnt, segment)
        self._add_segment_to_node(segment.lastpnt, segment.geom.coords[-1], segment.firstpnt, segment)


    def _add_segment_to_node(self, nid, geom, targetid, segment):
        """ Make a connection between node and segment.
        """
        if nid in self.nodes:
            node = self.nodes[nid]
        else:
            node = RouteGraphPoint(nid, geom)
            self.nodes[nid] = node

        node.edges.append(segment)
        node.neighbours.append(targetid)


    def build_directed_graph(self):
        """ Make a directed graph out of the collection of segments.
        """
        endpoints = self._mark_subgraphs()

        if len(endpoints) > 1:
            # Multiple subnets, create artificial connections.
            danglings = self._connect_subgraphs(endpoints)
        else:
            # Simple case. We only have a single subnet
            danglings = endpoints[0]

        if len(danglings) == 0:
            # TODO special case: circular way
            assert(not "circular way")
            pass
        elif len(danglings) == 1:
            # TODO special case: circular way with dangling string
            assert(not "circular dangling way")
            pass
        elif len(danglings) == 2:
            # special case: good route
            # XXX proper graph building needed
            self.first_segment = danglings[0].edges[0]
            current = self.first_segment
            while current:
                if current.connection:
                    current.forward = current.connection[0]
                    current = current.forward
                else:
                    current = None
        else:
            self._compute_main_route(danglings)



    def get_main_geometry(self):
        """Return an unbroken line string for the complete geometry.
        """
        coords = []
        current = self.first_segment
        lastpoint = current.firstpnt
        while current:
            if lastpoint == current.firstpnt:
                coords.extend(current.geom.coords)
            else:
                coords.extend(current.geom.coords[::-1])
            current = current.forward
        return LineString(coords)

    def _compute_main_route(self, startpoints):
        """ Makes the undirected graph directed and
            computes the main route.

            Spagetti-Algorithm:
            do a Dikstra-like forward search (for the shortest path)
            up to the point where all the starting points meet. Then
            take the two longest of the paths and use that as the
            main path.
        """
        # todolist. Entries are (dist, startnode, nextpoint)
        todo = PriorityQueue()
        # initial fill
        for s in startpoints:
            todo.put((0, s, self.nodes[s]))

        # initialise the point store on the nodes
        for n in self.nodes.itervalues():
            n.dikstra = [None for x in range(len(startpoints))]

        centerpoint = None
        while not todo.empty():
            dist, startnode, currentpt = todo.get()

            for nxt in currentpt.neighbours:
                nxtpt = self.nodes[nxt]
                newdst = nxtpt.distnace_to(currentpt)
                if nxtpt.dikstra[startnode] is None or nxtpt.dikstra[startnode][1] > newdst:
                    # found a better solution, queue
                    nxtpt.dikstra[startnode] = (newdst, currentpt)
                    todo.put((newdst, startnode, nxtpt))
                if not None in nxtpt.dikstra:
                    # we have finally met in a point, stop here
                    centerpoint = nxtpt
                    break
            if centerpoint is not None:
                break

        if centerpoint is None:
            pass  

        

    def _connect_subgraphs(self, endpoints):
        """Find the shortest connections between unconnected subgraphs.

           Returns the OSM IDs for all remaining endpoints.

           XXX This algorithm leaves circular parts dangeling.
        """
        # Get rid of circular subnets without an end
        zeropnts = filter(lambda x : x, endpoints)
        netids = range(len(zeropnts))
        finalendpoints = set()
        for pts in zeropnts:
            finalendpoints.update(pts)
            
        # compute all possible connections between subnets
        connections = []
        for frmnet in netids:
            for tonet in netids:
                if frmnet != tonet:
                    conn = [frmnet, None, tonet, None, float("inf")]
                    # find the shortest connection
                    for frmpnt in zeropnts[frmnet]:
                        for topnt in zeropnts[tonet]:
                            pdist = frmpnt.distance_to(topnt)
                            if pdist < conn[4]:
                                conn[1] = frmpnt
                                conn[3] = topnt
                                conn[4] = pdist
                    connections.append(conn)
        # sort by distance
        connections.sort(cmp=lambda x,y: cmp(x[4], y[4]),reverse=True)

        # now keep connecting until we have a single graph
        for (frmnet, frmpt, tonet, topt, dist) in connections:
            if netids[frmnet] != netids[tonet]:
                # add the virtual connection
                geom = LineString(frmpt.coords, topt.coords)
                segment = RouteGraphSegment(-1, [], geom, frmpt.nodeid, topt.nodeid)
                frmpt.edges.append(segment)
                frmpt.neighbours.append(topt.nodeid)
                topt.edges.append(segment)
                topt.neighbours.append(frmpt.nodeid)
                # remove final points
                finalendpoints.remove(topt)
                finalendpoints.remove(frmpt)
                # and join the nets
                oldsubid = netids[tonet]
                newsubid = netids[frmnet]
                netids = [newsubid if x == oldsubid else x for x in netids]

                # are we done yet? (i.e. is there still more than one subnet)
                for x in netids[1:]:
                    if x != netids[0]:
                        break
                else:
                    break
                            
        return [x.nodeid for x in finalendpoints]


    def _mark_subgraphs(self):
        """Go through the net and mark for each point to which subgraph
           it belongs. Returns for each subnets the endpoints (a list of
           lists). Endpoints are defined as points that have only one
           outgoing edge.

           XXX circular and networky stuff needs to be handled here already?
        """
        subnet = 0
        endpoints = []
        for pntid, pnt in self.nodes.iteritems():
            if pnt.subnet < 0:
                # new subnet, follow the net and mark all points
                # with the subnet id
                subnetendpoints = []
                todo = set([pntid,])
                while todo:
                    nxtid = todo.pop()
                    nxt = self.nodes[nxtid]
                    if nxt.subnet < 0:
                        nxt.subnet = subnet
                        todo.update(nxt.neighbours)
                        if len(nxt.edges) == 1:
                            subnetendpoints.append(nxt)
                subnet += 1
                endpoints.append(subnetendpoints)


                
        return endpoints
