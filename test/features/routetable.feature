Feature: Route table from RouteSegments

    Background:
      Given the following tag sets
       | name   | tags |
       | HIKING | 'type' : 'route', 'route' : 'hiking', 'name' : 'x' |

    Scenario: Simple ways
      Given a 0.001 node grid
        | 1 | 2 | 3 |   |   |
        | 4 | 5 | 6 | 7 | 8 |
        |   | 9 | 10| 11| 12|
      And the osm data
        | id | data       | tags |
        | W1 | 1,2,3      | |
        | W2 | 4,5        | |
        | W3 | 5,6        | |
        | W4 | 7,8        | |
        | W5 | 9,10,11,12 | |
        | R1 | W1     | 'type' : 'route', 'route' : 'hiking', 'name' : 'foo' |
        | R2 | W2,W3  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bar' |
        | R3 | W4,W5  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bazz' |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | foo  | 1, 2, 3 |
        | 2  | bar  | 4, 5, 6 |
        | 3  | bazz | (7, 8), (12, 11, 10, 9)  |

    Scenario: Fitting at the end takes precedence over close fit at beginning
      Given a 0.001 node grid
        | 1 | 2 | 3 | 4 |
        |   | 5 |   | 6 |
        |   | 7 | 8 |   |
      And the osm data
        | id | data       | tags |
        | W1 | 1,2        | |
        | W2 | 2,3,4      | |
        | W3 | 2,5        | |
        | W4 | 5,7,8      | |
        | W5 | 6,4        | |
        | R1 | W1,W2,W5,W3,W4  | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | x    | (1, 2, 3, 4, 6), (2, 5, 7, 8) |

    Scenario: Fitting at the end takes precedence over close fit at beginning for subroutes
      Given a 0.001 node grid
        | 1 | 2 | 3 | 4 |
        |   |   |   | 5 |
        | 9 | 8 | 7 | 6 |
      And the osm data
        | id | data       | tags |
        | W1 | 1,2        | |
        | W2 | 2,3,4      | |
        | W3 | 9,8        | |
        | W4 | 8,7        | |
        | W5 | 7,6,5      | |
        | R1 | W1,W2,R2,W3 | HIKING |
        | R2 | W4,W5       | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a RelationHierarchy 'routehier' with subset: tags->'type' = 'route' AND tags->'route' = 'hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking' and 'routehier'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | x    | (1, 2, 3, 4), (5, 6, 7, 8, 9) |
        | 2  | x    | 8, 7, 6, 5 |

    Scenario: Route with roundabout
      Given a 0.001 node grid
        |   |   | 3 |   |   |
        | 1 | 2 |   | 4 | 5 |
        |   |   | 6 |   |   |
      And the osm data
        | id | data      | tags |
        | W1 | 1,2       | |
        | W2 | 2,3,4,6,2 | |
        | W3 | 4,5       | |
        | R1 | W1,W2,W3  | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | x    | (1, 2, 3, 4, 6, 2), (4, 5) |

    Scenario: Segmented route
      Given a 0.001 node grid
        |   |   | 1 |   |   |
        | 2 | 3 | 4 | 5 | 6 |
      And the osm data
        | id | data      | tags |
        | W1 | 2,3,4     | |
        | W2 | 4,1       | |
        | W3 | 4,5,6     | |
        | R1 | W1, W2    | HIKING |
        | R2 | W2, W3    | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | x    | 2, 3, 4, 1 |
        | 2  | x    | 1, 4, 5, 6 |

    Scenario: Balloon route with duplicate
      Given a 0.001 node grid
        |   | 2 |   |   |
        | 1 |   | 4 | 5 |
        |   | 3 |   |   |
      And the osm data
        | id | data      | tags |
        | W1 | 1,2,4     | |
        | W2 | 1,3,4     | |
        | W3 | 4,5       | |
        | R1 | W3,W1,W2,W3 | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | x    | 5, 4, 2, 1, 3, 4, 5 |

    Scenario: Balloon route with side track
      Given a 0.001 node grid
        |   |   | 2 |   |   |
        | 6 | 1 |   | 4 | 5 |
        |   |   | 3 |   |   |
      And the osm data
        | id | data      | tags |
        | W1 | 5,4,3,1,2,4 | |
        | W2 | 1,6       | |
        | R1 | W1        | HIKING |
        | R2 | W2        | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | x    | 5, 4, 3, 1, 2, 4 |
        | 2  | x    | 1, 6 |


    Scenario: Round route with many ways and with parallel route
      Given a 0.001 node grid
        | 1 | 2 | 3 | 4 | 5 | 6 |
        | 7 |   |   |   |   | 8 |
        | 9 |   |   |   |   | 10|
        | 11|   |   |   |   | 12|
        | 13| 14| 15| 16| 17| 18|
      And the osm data
        | id | data       | tags |
        | W1 | 1,2,3      | |
        | W2 | 5,4,3      | |
        | W3 | 5,6        | |
        | W4 | 6,8,10,12  | |
        | W5 | 16,17,18,12| |
        | W6 | 15,16      | |
        | W7 | 15,14,13   | |
        | W8 | 1,7,9,11,13| |
        | R1 | W2,W3      | HIKING |
        | R2 | W1,W2,W3,W4,W5,W6,W7,W8 | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | x    | 3, 4, 5, 6 |
        | 2  | x    | 1, 2, 3, 4, 5, 6, 8, 10, 12, 18, 17, 16, 15, 14, 13, 11, 9, 7, 1 |

    Scenario: Subrelations
      Given a 0.001 node grid
          | 1 | 2 | 3 | 4 |
          |   |   |   |   |
          |   |   | 6 | 5 |
      And the osm data
          | id | data  | tags |
          | W1 | 1,2,3 | |
          | W2 | 6,5,4 | |
          | R1 | W1    | HIKING |
          | R2 | W2    | HIKING |
          | R9 | R2,R1 | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
          | id | name | geom    |
          | 1  | x    | 1, 2, 3 |
          | 2  | x    | 6, 5, 4 |
          | 9  | x    | (6, 5, 4), (3, 2, 1) |

    Scenario: Relation with mixed members
      Given a 0.0001 node grid
          | 1 |   |   |
          | 2 | 3 | 4 |
      And the osm data
          | id | data   | tags |
          | W1 | 1,2    | |
          | W2 | 2,3    | |
          | W3 | 3,4    | |
          | R1 | W1,R2,W3 | HIKING |
          | R2 | W2       | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a RelationHierarchy 'routehier' with subset: tags->'type' = 'route' AND tags->'route' = 'hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking' and 'routehier'
      Then table HikingRoutes consists of
          | id | name | geom |
          | 1  | x    | 1, 2, 3, 4 |
          | 2  | x    | 2, 3       |

    Scenario: Self-contained route
      Given a 0.0001 node grid
          | 1 | 2 | 3 |
      And the osm data
          | id | data   | tags |
          | W1 | 1,2,3  | |
          | R1 | W1, R2 | HIKING |
          | R2 | R1     | HIKING |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Then table HikingRoutes consists of
          | id | name | geom |
          | 1  | x    | 0.0 0.0, 0.0001 0.0, 0.0002 0.0 |
          | 2  | x    | 0.0 0.0, 0.0001 0.0, 0.0002 0.0 |


    Scenario: Remove relation
      Given a 0.0001 node grid
        | 1 | 2 | 3 |   |   |
        | 4 | 5 | 6 | 7 | 8 |
        |   | 9 | 10| 11| 12|
      And the osm data
        | id | data       | tags |
        | W1 | 1,2,3      | |
        | W2 | 4,5        | |
        | W3 | 5,6        | |
        | W4 | 7,8        | |
        | W5 | 9,10,11,12 | |
        | R1 | W1     | 'type' : 'route', 'route' : 'hiking', 'name' : 'foo' |
        | R2 | W2,W3  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bar' |
        | R3 | W4,W5  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bazz' |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Given an update of osm data
        | action | id | data      | tags |
        | D      | R1 | | |
      When updating table Hiking
      And updating table HikingRoutes
      Then table HikingRoutes consists of
        | id | name | geom |
        | 2  | bar  | 0.0 0.0001, 0.0001 0.0001, 0.0002 0.0001 |
        | 3  | bazz | (0.0003 0.0001, 0.0004 0.0001), (0.0004 0.0002, 0.0003 0.0002, 0.0002 0.0002, 0.0001 0.0002) |

    Scenario: Rename relation
      Given a 0.0001 node grid
        | 1 | 2 | 3 |   |   |
        | 4 | 5 | 6 | 7 | 8 |
        |   | 9 | 10| 11| 12|
      And the osm data
        | id | data       | tags |
        | W1 | 1,2,3      | |
        | W2 | 4,5        | |
        | W3 | 5,6        | |
        | W4 | 7,8        | |
        | W5 | 9,10,11,12 | |
        | R1 | W1     | 'type' : 'route', 'route' : 'hiking', 'name' : 'foo' |
        | R2 | W2,W3  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bar' |
        | R3 | W4,W5  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bazz' |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Given an update of osm data
        | action | id | data   | tags |
        | M      | R1 | W1     | 'type' : 'route', 'route' : 'hiking', 'name' : 'FOO' |
      When updating table Hiking
      And updating table HikingRoutes
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | FOO  | 0.0 0.0, 0.0001 0.0, 0.0002 0.0 |
        | 2  | bar  | 0.0 0.0001, 0.0001 0.0001, 0.0002 0.0001 |
        | 3  | bazz | (0.0003 0.0001, 0.0004 0.0001), (0.0004 0.0002, 0.0003 0.0002, 0.0002 0.0002, 0.0001 0.0002) |

    Scenario: Add relation
      Given a 0.0001 node grid
        | 1 | 2 | 3 |   |   |
        | 4 | 5 | 6 | 7 | 8 |
        |   | 9 | 10| 11| 12|
      And the osm data
        | id | data       | tags |
        | W1 | 1,2,3      | |
        | W2 | 4,5        | |
        | W3 | 5,6        | |
        | W4 | 7,8        | |
        | W5 | 9,10,11,12 | |
        | R2 | W2,W3  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bar' |
        | R3 | W4,W5  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bazz' |
      When constructing a RouteSegments table 'Hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking'
      Given an update of osm data
        | action | id | data   | tags |
        | A      | R1 | W1     | 'type' : 'route', 'route' : 'hiking', 'name' : 'foo' |
      When updating table Hiking
      And updating table HikingRoutes
      Then table HikingRoutes consists of
        | id | name | geom |
        | 1  | foo  | 0.0 0.0, 0.0001 0.0, 0.0002 0.0 |
        | 2  | bar  | 0.0 0.0001, 0.0001 0.0001, 0.0002 0.0001 |
        | 3  | bazz | (0.0003 0.0001, 0.0004 0.0001), (0.0004 0.0002, 0.0003 0.0002, 0.0002 0.0002, 0.0001 0.0002) |

    Scenario: Change a super relation
      Given a 0.0001 node grid
        | 1 | 2 | 3 |   |   |
        | 4 | 5 | 6 | 7 | 8 |
        |   | 9 | 10| 11| 12|
      And the osm data
        | id | data       | tags |
        | W1 | 1,2,3      | |
        | W2 | 4,5        | |
        | W3 | 5,6        | |
        | W4 | 7,8        | |
        | W5 | 9,10,11,12 | |
        | R2 | W2,W3  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bar' |
        | R3 | W4,W5  | 'type' : 'route', 'route' : 'hiking', 'name' : 'bazz' |
        | R4 | R2,R3  | 'type' : 'route', 'route' : 'hiking', 'name' : 'sup' |
      When constructing a RouteSegments table 'Hiking'
      And constructing a RelationHierarchy 'routehier' with subset: tags->'type' = 'route' AND tags->'route' = 'hiking'
      And constructing a Routes table 'HikingRoutes' from 'Hiking' and 'routehier'
      Given an update of osm data
        | action | id | data     | tags |
        | M      | R2 | W1,W2,W3 | 'type' : 'route', 'route' : 'hiking', 'name' : 'foo' |
      When updating table Hiking
      And updating table routehier
      And updating table HikingRoutes
      Then table HikingRoutes consists of
        | id | name | geom |
        | 2  | foo  | (0.0002 0.0, 0.0001 0.0, 0.0 0.0), (0.0 0.0001, 0.0001 0.0001, 0.0002 0.0001) |
        | 3  | bazz | (0.0003 0.0001, 0.0004 0.0001), (0.0004 0.0002, 0.0003 0.0002, 0.0002 0.0002, 0.0001 0.0002) |
        | 4  | sup | (0.0002 0.0, 0.0001 0.0, 0.0 0.0), (0.0 0.0001, 0.0001 0.0001, 0.0002 0.0001), (0.0003 0.0001, 0.0004 0.0001), (0.0004 0.0002, 0.0003 0.0002, 0.0002 0.0002, 0.0001 0.0002) |

