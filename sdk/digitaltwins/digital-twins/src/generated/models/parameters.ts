/*
 * Copyright (c) Microsoft Corporation.
 * Licensed under the MIT License.
 *
 * Code generated by Microsoft (R) AutoRest Code Generator.
 * Changes may cause incorrect behavior and will be lost if the code is regenerated.
 */

import {
  OperationParameter,
  OperationURLParameter,
  OperationQueryParameter,
  QueryCollectionFormat
} from "@azure/core-http";
import {
  QuerySpecification as QuerySpecificationMapper,
  EventRoute as EventRouteMapper
} from "../models/mappers";

export const contentType: OperationParameter = {
  parameterPath: ["options", "contentType"],
  mapper: {
    defaultValue: "application/json",
    isConstant: true,
    serializedName: "Content-Type",
    type: {
      name: "String"
    }
  }
};

export const models: OperationParameter = {
  parameterPath: ["options", "models"],
  mapper: {
    constraints: {
      MinItems: 1,
      UniqueItems: true
    },
    serializedName: "models",
    type: {
      name: "Sequence",
      element: { type: { name: "any" } }
    }
  }
};

export const $host: OperationURLParameter = {
  parameterPath: "$host",
  mapper: {
    serializedName: "$host",
    required: true,
    type: {
      name: "String"
    }
  },
  skipEncoding: true
};

export const apiVersion: OperationQueryParameter = {
  parameterPath: "apiVersion",
  mapper: {
    defaultValue: "2020-05-31-preview",
    isConstant: true,
    serializedName: "api-version",
    type: {
      name: "String"
    }
  }
};

export const dependenciesFor: OperationQueryParameter = {
  parameterPath: ["options", "dependenciesFor"],
  mapper: {
    serializedName: "dependenciesFor",
    type: {
      name: "Sequence",
      element: { type: { name: "String" } }
    }
  },
  collectionFormat: QueryCollectionFormat.Csv
};

export const includeModelDefinition: OperationQueryParameter = {
  parameterPath: ["options", "includeModelDefinition"],
  mapper: {
    serializedName: "includeModelDefinition",
    type: {
      name: "Boolean"
    }
  }
};

export const maxItemCount: OperationParameter = {
  parameterPath: ["options", "digitalTwinModelsListOptions", "maxItemCount"],
  mapper: {
    defaultValue: -1,
    serializedName: "x-ms-max-item-count",
    type: {
      name: "Number"
    }
  }
};

export const id: OperationURLParameter = {
  parameterPath: "id",
  mapper: {
    serializedName: "id",
    required: true,
    type: {
      name: "String"
    }
  }
};

export const contentType1: OperationParameter = {
  parameterPath: ["options", "contentType"],
  mapper: {
    defaultValue: "application/json-patch+json",
    isConstant: true,
    serializedName: "Content-Type",
    type: {
      name: "String"
    }
  }
};

export const updateModel: OperationParameter = {
  parameterPath: "updateModel",
  mapper: {
    serializedName: "updateModel",
    required: true,
    type: {
      name: "Sequence",
      element: { type: { name: "any" } }
    }
  }
};

export const nextLink: OperationURLParameter = {
  parameterPath: "nextLink",
  mapper: {
    serializedName: "nextLink",
    required: true,
    type: {
      name: "String"
    }
  },
  skipEncoding: true
};

export const querySpecification: OperationParameter = {
  parameterPath: "querySpecification",
  mapper: QuerySpecificationMapper
};

export const twin: OperationParameter = {
  parameterPath: "twin",
  mapper: {
    serializedName: "twin",
    required: true,
    type: {
      name: "any"
    }
  }
};

export const ifNoneMatch: OperationParameter = {
  parameterPath: ["options", "ifNoneMatch"],
  mapper: {
    defaultValue: "*",
    isConstant: true,
    serializedName: "If-None-Match",
    type: {
      name: "String"
    }
  }
};

export const ifMatch: OperationParameter = {
  parameterPath: ["options", "ifMatch"],
  mapper: {
    serializedName: "If-Match",
    type: {
      name: "String"
    }
  }
};

export const patchDocument: OperationParameter = {
  parameterPath: "patchDocument",
  mapper: {
    serializedName: "patchDocument",
    required: true,
    type: {
      name: "Sequence",
      element: { type: { name: "any" } }
    }
  }
};

export const relationshipId: OperationURLParameter = {
  parameterPath: "relationshipId",
  mapper: {
    serializedName: "relationshipId",
    required: true,
    type: {
      name: "String"
    }
  }
};

export const relationship: OperationParameter = {
  parameterPath: ["options", "relationship"],
  mapper: {
    serializedName: "relationship",
    type: {
      name: "any"
    }
  }
};

export const patchDocument1: OperationParameter = {
  parameterPath: ["options", "patchDocument"],
  mapper: {
    serializedName: "patchDocument",
    type: {
      name: "Sequence",
      element: { type: { name: "any" } }
    }
  }
};

export const relationshipName: OperationQueryParameter = {
  parameterPath: ["options", "relationshipName"],
  mapper: {
    serializedName: "relationshipName",
    type: {
      name: "String"
    }
  }
};

export const telemetry: OperationParameter = {
  parameterPath: "telemetry",
  mapper: {
    serializedName: "telemetry",
    required: true,
    type: {
      name: "any"
    }
  }
};

export const dtId: OperationParameter = {
  parameterPath: "dtId",
  mapper: {
    serializedName: "dt-id",
    required: true,
    type: {
      name: "String"
    }
  }
};

export const timestamp: OperationParameter = {
  parameterPath: ["options", "timestamp"],
  mapper: {
    serializedName: "dt-timestamp",
    type: {
      name: "String"
    }
  }
};

export const componentPath: OperationURLParameter = {
  parameterPath: "componentPath",
  mapper: {
    serializedName: "componentPath",
    required: true,
    type: {
      name: "String"
    }
  }
};

export const maxItemCount1: OperationParameter = {
  parameterPath: ["options", "eventRoutesListOptions", "maxItemCount"],
  mapper: {
    defaultValue: -1,
    serializedName: "x-ms-max-item-count",
    type: {
      name: "Number"
    }
  }
};

export const eventRoute: OperationParameter = {
  parameterPath: ["options", "eventRoute"],
  mapper: EventRouteMapper
};
