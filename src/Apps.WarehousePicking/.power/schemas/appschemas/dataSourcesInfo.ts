/*!
 * Copyright (C) Microsoft Corporation. All rights reserved.
 * This file is auto-generated. Do not modify it manually.
 * Changes to this file may be overwritten.
 */

export const dataSourcesInfo = {
  "almlab_warehouseitems": {
    "tableId": "",
    "version": "",
    "primaryKey": "almlab_warehouseitemid",
    "dataSourceType": "Dataverse",
    "apis": {}
  },
  "almlab_warehousetransactions": {
    "tableId": "",
    "version": "",
    "primaryKey": "almlab_warehousetransactionid",
    "dataSourceType": "Dataverse",
    "apis": {}
  },
  "almlab_warehouselocations": {
    "tableId": "",
    "version": "",
    "primaryKey": "almlab_warehouselocationid",
    "dataSourceType": "Dataverse",
    "apis": {}
  },
  "almlab_products": {
    "tableId": "",
    "version": "",
    "primaryKey": "almlab_productid",
    "dataSourceType": "Dataverse",
    "apis": {}
  },
  "OpenFoodFacts": {
    "tableId": "",
    "version": "",
    "dataSourceType": "Connector",
    "apis": {
      "GetProductByBarcode": {
        "path": "/product/{barcode}.json",
        "method": "GET",
        "parameters": [
          { "name": "barcode", "in": "path", "required": true, "type": "string" }
        ]
      }
    }
  }
};
