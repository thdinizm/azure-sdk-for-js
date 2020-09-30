// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

import { odata, TableClient } from "@azure/data-tables";

// Load the .env file if it exists
import * as dotenv from "dotenv";
dotenv.config();

const tablesUrl = process.env["TABLES_URL"] || "";
const sasToken = process.env["SAS_TOKEN"] || "";

export async function createAndDeleteEntities() {
  console.log("== Create and delete entities Sample ==");

  // Note that this sample assumes that a table with tableName exists
  const tableName = "OfficeSupplies4p1";

  // See authenticationMethods sample for other options of creating a new client
  const client = new TableClient(`${tablesUrl}${sasToken}`, tableName);

  const partitionKey = "Stationery";
  const marker: Entity = {
    partitionKey,
    rowKey: "1",
    name: "Markers",
    price: 5.0,
    quantity: 34
  };

  const planner: Entity = {
    partitionKey,
    rowKey: "2",
    name: "Planner",
    price: 7.0,
    quantity: 34
  };

  // create entities for marker and planner
  await client.createEntity(marker);
  await client.createEntity(planner);

  // List all entities with PartitionKey "Stationery"
  const listResults = client.listEntities<Entity>({
    queryOptions: { filter: odata`PartitionKey eq ${partitionKey}` }
  });

  for await (const product of listResults) {
    console.log(`${product.name}: ${product.price}`);
  }

  // List all entities with a price less than 6.0
  const priceListResults = client.listEntities<Entity>({
    queryOptions: { filter: odata`price le 6` }
  });

  console.log("-- Products with a price less or equals to 6.00");
  for await (const product of priceListResults) {
    console.log(`${product.name}: ${product.price}`);
  }
}

interface Entity {
  partitionKey: string;
  rowKey: string;
  name: string;
  price: number;
  quantity: number;
}

export async function main() {
  await createAndDeleteEntities();
}

main().catch((err) => {
  console.error("The sample encountered an error:", err);
});
