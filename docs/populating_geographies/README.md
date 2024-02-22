# Geospatial Reference Data

Geospatial reference data supports the following features in Driver's Seat.

* **Community Insights** <br/>
  Gig Activities (from Argyle) are associated to the metro area in which they occurred (`region_metro_area`).  This is the basis for summarizing average hourly pay for the Community Insights/Average Hourly Pay feature.
  <br/>

* **User Metro Area Assignment** <br/>
  When a user updates their postal code, it is matched to the `region_postal_code` table and they are associated to a Metro Area.

As a result, a geospatial reference data is required.  This document outlines how to seed the database tables with data from the Census Bureau Tiger DB.

## Data Sources

All data comes from the Census Bureau Tiger Web DB
| data type               | rows  | source  |
|--                       |--     |--       |
| `region_state`          | 56    | [States (80)](https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_ACS2023/MapServer/80) |
| `region_county`         | 3,234      | [Counties (82)](https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_ACS2023/MapServer/82) |
| `region_metro_area`     | 939   | [Metropolitan Statistical Areas (93)](https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_ACS2023/MapServer/93) <br/> [Micropolitan Statistical Areas (91)](https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_ACS2023/MapServer/91) |
| `region_postal_code`    | 33,791| [Zip Code Tabulation Areas (2)](https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/tigerWMS_ACS2023/MapServer/2) |

## Populating Geospatial Reference Data

1. Start an Interactive Elixir session

    ```shell
    iex -S mix
    ```

2. Execute code to retrieve and populate regions.  **These statements need to be run in the order presented**

    ```elixir
    DriversSeatCoop.Regions.CensusTigerDB.update_states()               # takes about 5 minutes
    DriversSeatCoop.Regions.CensusTigerDB.update_counties()             # takes about 15 minutes
    DriversSeatCoop.Regions.CensusTigerDB.update_metropolitan_areas()   # takes about 10 minutes
    DriversSeatCoop.Regions.CensusTigerDB.update_micropolitan_areas()   # takes about 15 minutes
    DriversSeatCoop.Regions.CensusTigerDB.update_postal_codes()         # takes about 2-hours
    ```
