> HONOR C00 frozen specification — Round 8.
> Machine authority: `HONOR_OPENAPI.json` = `HONOR_OPENAPI_V1.json` = `HONOR_OPENAPI.yaml` (data-equivalent). This Markdown is generated from the machine contract; it is not an independent schema authority.

# Frozen API Contracts

AUTH_ROUTE_SET_V1: GET /login | POST /auth/login | POST /auth/recover | GET /auth/confirm | GET /auth/set-password | POST /auth/set-password | POST /auth/logout

## Production topology

- Browser business traffic: `/api/v1/...` -> same-origin Next.js BFF -> private FastAPI `http://api:8000/v1/...`.
- Public liveness only: Caddy `/healthz` -> private FastAPI `http://api:8000/healthz`.
- Owner readiness: browser `/api/readyz` -> authenticated Next.js BFF -> private FastAPI `http://api:8000/readyz`.
- FastAPI business `/v1/*` is never Internet-routable in production; browser CORS to FastAPI is not V1.

## Structured JSON and campaign-rule authority

Canonical JSONB structures referenced by OpenAPI are the exact files under `jsonschema/`; campaign rule values are further narrowed per key by `HONOR_CAMPAIGN_RULE_REGISTRY.json`. `campaign_terms_snapshots.id` identifies the normalized rule snapshot, but it is consumable only after an immutable matching `campaign_rule_set_commits` seal proves all 32 keys and chronology. UNKNOWN rule values are null and never become permission. Restriction execution semantics are frozen in `HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json`.

## Endpoint registry

| Method | FastAPI path | operationId | auth | idempotency | request schema | success statuses |
|---|---|---|---|---|---|---|
| GET | `/healthz` | `healthz` | PUBLIC | NOT_REQUIRED | `none` | 200 |
| GET | `/readyz` | `readyz` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| POST | `/v1/generation-runs` | `createGenerationRun` | OWNER_JWT_VIA_BFF | REQUIRED | `GenerationRunCreateRequest` | 202 |
| GET | `/v1/generation-runs/{id}` | `getGenerationRun` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| GET | `/v1/campaigns` | `listCampaigns` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| POST | `/v1/campaigns/import` | `importCampaign` | OWNER_JWT_VIA_BFF | REQUIRED | `CampaignImportRequest` | 202 |
| GET | `/v1/campaigns/{id}` | `getCampaign` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| POST | `/v1/uploads/intents` | `createUploadIntent` | OWNER_JWT_VIA_BFF | REQUIRED | `UploadIntentRequest` | 201 |
| POST | `/v1/uploads/{id}/complete` | `completeUpload` | OWNER_JWT_VIA_BFF | REQUIRED | `UploadCompleteRequest` | 200 |
| POST | `/v1/sources/import` | `importSource` | OWNER_JWT_VIA_BFF | REQUIRED | `SourceImportRequest` | 202 |
| GET | `/v1/sources/{id}` | `getSource` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| GET | `/v1/clips` | `listClips` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| GET | `/v1/clips/{id}` | `getClip` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| GET | `/v1/schedule/tomorrow` | `getTomorrowSchedule` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| POST | `/v1/posts` | `createPost` | OWNER_JWT_VIA_BFF | REQUIRED | `PostCreateRequest` | 201 |
| POST | `/v1/submissions` | `recordSubmission` | OWNER_JWT_VIA_BFF | REQUIRED | `SubmissionRequest` | 201 |
| POST | `/v1/analytics/check-ins` | `recordAnalyticsCheckin` | OWNER_JWT_VIA_BFF | REQUIRED | `AnalyticsObservationInput` | 201 |
| GET | `/v1/analytics/due` | `listDueAnalytics` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| POST | `/v1/payout-events` | `recordPayoutEvent` | OWNER_JWT_VIA_BFF | REQUIRED | `PayoutEventRequest` | 201 |
| GET | `/v1/finance/summary` | `getFinanceSummary` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| GET | `/v1/costs/summary` | `getCostSummary` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| POST | `/v1/polli/sessions` | `startPolliSession` | OWNER_JWT_VIA_BFF | REQUIRED | `PolliSessionCreateRequest` | 201 |
| POST | `/v1/polli/live/sessions` | `createPolliLiveSession` | OWNER_JWT_VIA_BFF | REQUIRED | `PolliLiveSessionRequest` | 201 |
| POST | `/v1/polli/query` | `queryPolli` | OWNER_JWT_VIA_BFF | REQUIRED | `PolliQueryRequest` | 200 |
| POST | `/v1/polli/sessions/{id}/end` | `endPolliSession` | OWNER_JWT_VIA_BFF | REQUIRED | `PolliSessionEndRequest` | 200 |
| GET | `/v1/owner-actions` | `listOwnerActions` | OWNER_JWT_VIA_BFF | NOT_REQUIRED | `none` | 200 |
| POST | `/v1/owner-actions/{id}/resolve` | `resolveOwnerAction` | OWNER_JWT_VIA_BFF | REQUIRED | `OwnerActionResolveRequest` | 200 |

## `GET /healthz` — `healthz`
Authorization: **PUBLIC**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[]
```

### Request body
No JSON request body.

### Responses
- `200` Alive
```json
{
  "$ref": "#/components/schemas/HealthResponse"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "const": "ok"
    },
    "service": {
      "type": "string",
      "const": "honor-api"
    },
    "time": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "status",
    "service",
    "time"
  ]
}
```

### Exact error codes
```json
{}
```

## `GET /readyz` — `readyz`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[]
```

### Request body
No JSON request body.

### Responses
- `200` Ready
```json
{
  "$ref": "#/components/schemas/ReadinessResponse"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "enum": [
        "ready",
        "not_ready"
      ]
    },
    "time": {
      "type": "string",
      "format": "date-time"
    },
    "checks": {
      "type": "object",
      "properties": {
        "database": {
          "type": "string",
          "enum": [
            "ok",
            "error"
          ]
        },
        "redis": {
          "type": "string",
          "enum": [
            "ok",
            "error"
          ]
        },
        "r2": {
          "type": "string",
          "enum": [
            "ok",
            "error"
          ]
        }
      },
      "additionalProperties": false,
      "required": [
        "database",
        "redis",
        "r2"
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "status",
    "time",
    "checks"
  ]
}
```
- `503` Not ready
```json
{
  "$ref": "#/components/schemas/Error_readyz_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `401` Authentication required
```json
{
  "$ref": "#/components/schemas/Error_readyz_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Authenticated non-owner forbidden
```json
{
  "$ref": "#/components/schemas/Error_readyz_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `POST /v1/generation-runs` — `createGenerationRun`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/GenerationRunCreateRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "target_date": {
      "type": "string",
      "format": "date"
    },
    "campaign_ids": {
      "type": "array",
      "items": {
        "type": "string",
        "format": "uuid"
      },
      "minItems": 0,
      "maxItems": 50
    },
    "social_account_ids": {
      "type": "array",
      "items": {
        "type": "string",
        "format": "uuid"
      },
      "minItems": 0,
      "maxItems": 20
    },
    "requested_constraints": {
      "$ref": "#/components/schemas/GenerationRequestedConstraintsV1"
    }
  },
  "additionalProperties": false,
  "required": [
    "target_date"
  ]
}
```

### Responses
- `202` Queued
```json
{
  "$ref": "#/components/schemas/GenerationRun"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "target_date": {
      "type": "string",
      "format": "date"
    },
    "state": {
      "$ref": "#/components/schemas/JobState"
    },
    "stage": {
      "type": "string",
      "enum": [
        "campaign_import",
        "rules_normalization",
        "source_ingest",
        "rights_verification",
        "transcription",
        "candidate_discovery",
        "candidate_scoring",
        "finalist_selection",
        "edit_plan",
        "audio_plan",
        "render",
        "qc",
        "schedule",
        "analytics_ingest",
        "payout_reconcile",
        "cost_reconcile",
        "backup"
      ]
    },
    "strategy_version": {
      "type": "string"
    },
    "budget_snapshot": {
      "$ref": "jsonschema/generation.budget_snapshot.v1.json"
    },
    "requested_constraints": {
      "$ref": "jsonschema/generation.requested_constraints.v1.json"
    },
    "selected_plan": {
      "anyOf": [
        {
          "$ref": "jsonschema/generation.selected_plan.v1.json"
        },
        {
          "type": "null"
        }
      ]
    },
    "correlation_id": {
      "type": "string",
      "format": "uuid"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "completed_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "target_date",
    "state",
    "stage",
    "strategy_version",
    "budget_snapshot",
    "requested_constraints",
    "selected_plan",
    "correlation_id",
    "created_at",
    "completed_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_createGenerationRun_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_createGenerationRun_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_createGenerationRun_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_createGenerationRun_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_createGenerationRun_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_createGenerationRun_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "COST_GOVERNOR_BLOCKED",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "IDEMPOTENCY_KEY_REUSED"
  ]
}
```

## `GET /v1/generation-runs/{id}` — `getGenerationRun`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "id",
    "in": "path",
    "required": true,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Run
```json
{
  "$ref": "#/components/schemas/GenerationRun"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "target_date": {
      "type": "string",
      "format": "date"
    },
    "state": {
      "$ref": "#/components/schemas/JobState"
    },
    "stage": {
      "type": "string",
      "enum": [
        "campaign_import",
        "rules_normalization",
        "source_ingest",
        "rights_verification",
        "transcription",
        "candidate_discovery",
        "candidate_scoring",
        "finalist_selection",
        "edit_plan",
        "audio_plan",
        "render",
        "qc",
        "schedule",
        "analytics_ingest",
        "payout_reconcile",
        "cost_reconcile",
        "backup"
      ]
    },
    "strategy_version": {
      "type": "string"
    },
    "budget_snapshot": {
      "$ref": "jsonschema/generation.budget_snapshot.v1.json"
    },
    "requested_constraints": {
      "$ref": "jsonschema/generation.requested_constraints.v1.json"
    },
    "selected_plan": {
      "anyOf": [
        {
          "$ref": "jsonschema/generation.selected_plan.v1.json"
        },
        {
          "type": "null"
        }
      ]
    },
    "correlation_id": {
      "type": "string",
      "format": "uuid"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "completed_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "target_date",
    "state",
    "stage",
    "strategy_version",
    "budget_snapshot",
    "requested_constraints",
    "selected_plan",
    "correlation_id",
    "created_at",
    "completed_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_getGenerationRun_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_getGenerationRun_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `404` Error
```json
{
  "$ref": "#/components/schemas/Error_getGenerationRun_404"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_getGenerationRun_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_getGenerationRun_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "404": [
    "NOT_FOUND"
  ]
}
```

## `GET /v1/campaigns` — `listCampaigns`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "limit",
    "in": "query",
    "required": false,
    "schema": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100,
      "default": 25
    }
  },
  {
    "name": "cursor",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "minLength": 1
    }
  },
  {
    "name": "status",
    "in": "query",
    "required": false,
    "schema": {
      "$ref": "#/components/schemas/CampaignStatus"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Campaigns
```json
{
  "$ref": "#/components/schemas/CampaignList"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/CampaignSummary"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_listCampaigns_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_listCampaigns_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_listCampaigns_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_listCampaigns_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `POST /v1/campaigns/import` — `importCampaign`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/CampaignImportRequest"
}
```
Resolved canonical request schema:
```json
{
  "oneOf": [
    {
      "$ref": "#/components/schemas/CampaignOwnerUrlImport"
    },
    {
      "$ref": "#/components/schemas/CampaignManualImport"
    },
    {
      "$ref": "#/components/schemas/CampaignOfficialApiImport"
    }
  ],
  "discriminator": {
    "propertyName": "method",
    "mapping": {
      "OWNER_URL": "#/components/schemas/CampaignOwnerUrlImport",
      "MANUAL": "#/components/schemas/CampaignManualImport",
      "OFFICIAL_API": "#/components/schemas/CampaignOfficialApiImport"
    }
  }
}
```

### Responses
- `202` Import accepted
```json
{
  "$ref": "#/components/schemas/CampaignImportAccepted"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "job_id": {
      "type": "string",
      "format": "uuid"
    },
    "status": {
      "type": "string",
      "const": "VERIFYING"
    },
    "correlation_id": {
      "type": "string",
      "format": "uuid"
    }
  },
  "additionalProperties": false,
  "required": [
    "campaign_id",
    "job_id",
    "status",
    "correlation_id"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_importCampaign_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_importCampaign_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_importCampaign_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_importCampaign_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_importCampaign_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_importCampaign_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "COST_GOVERNOR_BLOCKED",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "CONFLICT",
    "IDEMPOTENCY_KEY_REUSED"
  ]
}
```

## `GET /v1/campaigns/{id}` — `getCampaign`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "id",
    "in": "path",
    "required": true,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Campaign
```json
{
  "$ref": "#/components/schemas/CampaignDetail"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "campaign": {
      "$ref": "#/components/schemas/CampaignSummary"
    },
    "terms_snapshot_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "rules": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/CampaignRuleItem"
      },
      "minItems": 0,
      "maxItems": 100
    }
  },
  "additionalProperties": false,
  "required": [
    "campaign",
    "terms_snapshot_id",
    "rules"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_getCampaign_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_getCampaign_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `404` Error
```json
{
  "$ref": "#/components/schemas/Error_getCampaign_404"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_getCampaign_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_getCampaign_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "404": [
    "NOT_FOUND"
  ]
}
```

## `POST /v1/uploads/intents` — `createUploadIntent`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/UploadIntentRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "purpose": {
      "$ref": "#/components/schemas/UploadPurpose"
    },
    "filename": {
      "type": "string",
      "minLength": 1,
      "maxLength": 255
    },
    "content_type": {
      "type": "string",
      "minLength": 3,
      "maxLength": 255
    },
    "size_bytes": {
      "type": "integer",
      "minimum": 1,
      "maximum": 2147483648
    },
    "sha256": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$"
    }
  },
  "additionalProperties": false,
  "required": [
    "purpose",
    "filename",
    "content_type",
    "size_bytes",
    "sha256"
  ]
}
```

### Responses
- `201` Upload intent
```json
{
  "$ref": "#/components/schemas/UploadIntentResponse"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "upload_id": {
      "type": "string",
      "format": "uuid"
    },
    "state": {
      "type": "string",
      "const": "INTENT_CREATED"
    },
    "method": {
      "type": "string",
      "const": "PUT"
    },
    "upload_url": {
      "type": "string",
      "format": "uri"
    },
    "required_headers": {
      "type": "object",
      "additionalProperties": {
        "type": "string"
      }
    },
    "expires_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "upload_id",
    "state",
    "method",
    "upload_url",
    "required_headers",
    "expires_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_createUploadIntent_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_createUploadIntent_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_createUploadIntent_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_createUploadIntent_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_createUploadIntent_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_createUploadIntent_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "CONFLICT",
    "IDEMPOTENCY_KEY_REUSED"
  ]
}
```

## `POST /v1/uploads/{id}/complete` — `completeUpload`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  },
  {
    "name": "id",
    "in": "path",
    "required": true,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/UploadCompleteRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "size_bytes": {
      "type": "integer",
      "minimum": 1,
      "maximum": 2147483648
    },
    "sha256": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$"
    }
  },
  "additionalProperties": false,
  "required": [
    "size_bytes",
    "sha256"
  ]
}
```

### Responses
- `200` Verified upload
```json
{
  "$ref": "#/components/schemas/UploadRecord"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "purpose": {
      "$ref": "#/components/schemas/UploadPurpose"
    },
    "state": {
      "$ref": "#/components/schemas/UploadState"
    },
    "filename": {
      "type": "string"
    },
    "content_type": {
      "type": "string"
    },
    "size_bytes": {
      "type": "integer"
    },
    "sha256": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$"
    },
    "expires_at": {
      "type": "string",
      "format": "date-time"
    },
    "verified_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "purpose",
    "state",
    "filename",
    "content_type",
    "size_bytes",
    "sha256",
    "expires_at",
    "verified_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_completeUpload_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_completeUpload_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `404` Error
```json
{
  "$ref": "#/components/schemas/Error_completeUpload_404"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "UPLOAD_NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_completeUpload_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "UPLOAD_EXPIRED",
            "UPLOAD_MISMATCH"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_completeUpload_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "UPLOAD_MISMATCH",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_completeUpload_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_completeUpload_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "UPLOAD_MISMATCH",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "404": [
    "UPLOAD_NOT_FOUND"
  ],
  "409": [
    "IDEMPOTENCY_KEY_REUSED",
    "UPLOAD_EXPIRED",
    "UPLOAD_MISMATCH"
  ]
}
```

## `POST /v1/sources/import` — `importSource`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/SourceImportRequest"
}
```
Resolved canonical request schema:
```json
{
  "oneOf": [
    {
      "$ref": "#/components/schemas/SourceOwnerUrlImport"
    },
    {
      "$ref": "#/components/schemas/SourceManualUploadImport"
    },
    {
      "$ref": "#/components/schemas/SourceAuthorizedApiImport"
    }
  ],
  "discriminator": {
    "propertyName": "method",
    "mapping": {
      "OWNER_URL": "#/components/schemas/SourceOwnerUrlImport",
      "MANUAL_UPLOAD": "#/components/schemas/SourceManualUploadImport",
      "AUTHORIZED_API": "#/components/schemas/SourceAuthorizedApiImport"
    }
  }
}
```

### Responses
- `202` Source accepted
```json
{
  "$ref": "#/components/schemas/SourceImportAccepted"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "source_id": {
      "type": "string",
      "format": "uuid"
    },
    "job_id": {
      "type": "string",
      "format": "uuid"
    },
    "ingest_status": {
      "$ref": "#/components/schemas/SourceIngestStatus"
    },
    "correlation_id": {
      "type": "string",
      "format": "uuid"
    }
  },
  "additionalProperties": false,
  "required": [
    "source_id",
    "job_id",
    "ingest_status",
    "correlation_id"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_importSource_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_importSource_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN",
            "RIGHTS_UNVERIFIED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_importSource_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_importSource_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "RIGHTS_UNVERIFIED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_importSource_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_importSource_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN",
    "RIGHTS_UNVERIFIED"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "RIGHTS_UNVERIFIED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "CONFLICT",
    "IDEMPOTENCY_KEY_REUSED"
  ]
}
```

## `GET /v1/sources/{id}` — `getSource`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "id",
    "in": "path",
    "required": true,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Source
```json
{
  "$ref": "#/components/schemas/SourceRecord"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "origin_type": {
      "$ref": "#/components/schemas/SourceOrigin"
    },
    "source_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "provider": {
      "type": "string"
    },
    "external_source_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "title": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "sha256": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^[a-f0-9]{64}$"
        },
        {
          "type": "null"
        }
      ]
    },
    "duration_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "ingest_status": {
      "$ref": "#/components/schemas/SourceIngestStatus"
    },
    "eligibility": {
      "$ref": "#/components/schemas/SourceEligibility"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "origin_type",
    "source_url",
    "provider",
    "external_source_id",
    "title",
    "sha256",
    "duration_ms",
    "ingest_status",
    "eligibility",
    "created_at",
    "updated_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_getSource_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_getSource_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `404` Error
```json
{
  "$ref": "#/components/schemas/Error_getSource_404"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_getSource_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_getSource_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "404": [
    "NOT_FOUND"
  ]
}
```

## `GET /v1/clips` — `listClips`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "limit",
    "in": "query",
    "required": false,
    "schema": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100,
      "default": 25
    }
  },
  {
    "name": "cursor",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "minLength": 1
    }
  },
  {
    "name": "state",
    "in": "query",
    "required": false,
    "schema": {
      "$ref": "#/components/schemas/ClipState"
    }
  },
  {
    "name": "campaign_id",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  },
  {
    "name": "social_account_id",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Clips
```json
{
  "$ref": "#/components/schemas/ClipList"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/ClipSummary"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_listClips_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_listClips_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_listClips_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_listClips_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `GET /v1/clips/{id}` — `getClip`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "id",
    "in": "path",
    "required": true,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Clip
```json
{
  "$ref": "#/components/schemas/ClipDetail"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "clip": {
      "$ref": "#/components/schemas/ClipSummary"
    },
    "width": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 1
        },
        {
          "type": "null"
        }
      ]
    },
    "height": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 1
        },
        {
          "type": "null"
        }
      ]
    },
    "codec": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "file_size_bytes": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "sha256": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^[a-f0-9]{64}$"
        },
        {
          "type": "null"
        }
      ]
    },
    "download_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "download_url_expires_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "posting_recommendation": {
      "$ref": "#/components/schemas/PostingRecommendation"
    },
    "rule_snapshot_id": {
      "type": "string",
      "format": "uuid"
    },
    "rights_id": {
      "type": "string",
      "format": "uuid"
    },
    "edit_plan_id": {
      "type": "string",
      "format": "uuid"
    },
    "audio_plan_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "render_manifest_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "clip",
    "width",
    "height",
    "codec",
    "file_size_bytes",
    "sha256",
    "download_url",
    "download_url_expires_at",
    "posting_recommendation",
    "rule_snapshot_id",
    "rights_id",
    "edit_plan_id",
    "audio_plan_id",
    "render_manifest_id"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_getClip_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_getClip_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `404` Error
```json
{
  "$ref": "#/components/schemas/Error_getClip_404"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_getClip_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_getClip_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "404": [
    "NOT_FOUND"
  ]
}
```

## `GET /v1/schedule/tomorrow` — `getTomorrowSchedule`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[]
```

### Request body
No JSON request body.

### Responses
- `200` Schedule
```json
{
  "$ref": "#/components/schemas/TomorrowSchedule"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "target_date": {
      "type": "string",
      "format": "date"
    },
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/ScheduleItem"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "generated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "target_date",
    "items",
    "generated_at"
  ],
  "description": "Owner posting schedule as of generated_at. Items are current-authorized recommendations only; latest-rights revalidation occurs at response time and historical clips remain unchanged if later rights narrow/revoke."
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_getTomorrowSchedule_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_getTomorrowSchedule_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_getTomorrowSchedule_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `POST /v1/posts` — `createPost`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/PostCreateRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "clip_id": {
      "type": "string",
      "format": "uuid"
    },
    "social_account_id": {
      "type": "string",
      "format": "uuid"
    },
    "platform": {
      "$ref": "#/components/schemas/Platform"
    },
    "published_at": {
      "type": "string",
      "format": "date-time"
    },
    "post_url": {
      "type": "string",
      "format": "uri"
    },
    "platform_post_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "native_audio_used": {
      "anyOf": [
        {
          "$ref": "#/components/schemas/PostNativeAudioUsedV1"
        },
        {
          "type": "null"
        }
      ]
    },
    "owner_notes": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 4000
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "clip_id",
    "social_account_id",
    "platform",
    "published_at",
    "post_url",
    "platform_post_id",
    "native_audio_used",
    "owner_notes"
  ]
}
```

### Responses
- `201` Post
```json
{
  "$ref": "#/components/schemas/PostRecord"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "clip_id": {
      "type": "string",
      "format": "uuid"
    },
    "social_account_id": {
      "type": "string",
      "format": "uuid"
    },
    "platform": {
      "$ref": "#/components/schemas/Platform"
    },
    "published_at": {
      "type": "string",
      "format": "date-time"
    },
    "post_url": {
      "type": "string",
      "format": "uri"
    },
    "platform_post_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "native_audio_used": {
      "anyOf": [
        {
          "$ref": "jsonschema/post.native_audio_used.v1.json"
        },
        {
          "type": "null"
        }
      ]
    },
    "owner_notes": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "status": {
      "$ref": "#/components/schemas/PostStatus"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "clip_id",
    "social_account_id",
    "platform",
    "published_at",
    "post_url",
    "platform_post_id",
    "native_audio_used",
    "owner_notes",
    "status",
    "created_at",
    "updated_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_createPost_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_createPost_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_createPost_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_createPost_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_createPost_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_createPost_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "CONFLICT",
    "IDEMPOTENCY_KEY_REUSED",
    "INVALID_STATE_TRANSITION"
  ]
}
```

## `POST /v1/submissions` — `recordSubmission`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/SubmissionRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "status": {
      "$ref": "#/components/schemas/SubmissionStatus",
      "description": "On create: PENDING|SUBMITTED|NOT_REQUIRED|UNKNOWN. On update: requested state must follow canonical transition graph; ACCEPTED/REJECTED are valid only from SUBMITTED or UNKNOWN.",
      "x-honor-creation-allowed-values": [
        "PENDING",
        "SUBMITTED",
        "NOT_REQUIRED",
        "UNKNOWN"
      ],
      "x-honor-transition-allowed-values-by-current-state": {
        "PENDING": [
          "SUBMITTED",
          "NOT_REQUIRED",
          "UNKNOWN"
        ],
        "SUBMITTED": [
          "ACCEPTED",
          "REJECTED",
          "UNKNOWN"
        ],
        "UNKNOWN": [
          "PENDING",
          "SUBMITTED",
          "NOT_REQUIRED",
          "ACCEPTED",
          "REJECTED"
        ],
        "ACCEPTED": [],
        "REJECTED": [],
        "NOT_REQUIRED": []
      }
    },
    "submitted_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "submission_reference": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 2000
        },
        {
          "type": "null"
        }
      ]
    },
    "evidence_upload_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "campaign_id",
    "post_id",
    "status",
    "submitted_at",
    "submission_reference",
    "evidence_upload_id"
  ]
}
```

### Responses
- `201` Submission
```json
{
  "$ref": "#/components/schemas/SubmissionRecord"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "submitted_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "submission_reference": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "status": {
      "$ref": "#/components/schemas/SubmissionStatus"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "campaign_id",
    "post_id",
    "submitted_at",
    "submission_reference",
    "status",
    "created_at",
    "updated_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_recordSubmission_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_recordSubmission_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_recordSubmission_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_recordSubmission_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_recordSubmission_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_recordSubmission_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "CONFLICT",
    "IDEMPOTENCY_KEY_REUSED",
    "INVALID_STATE_TRANSITION"
  ]
}
```

## `POST /v1/analytics/check-ins` — `recordAnalyticsCheckin`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/AnalyticsObservationInput"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "checkin_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "observed_at": {
      "type": "string",
      "format": "date-time"
    },
    "views": {
      "type": "integer",
      "minimum": 0
    },
    "qualified_views": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "likes": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "comments": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "shares": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "saves": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "watch_time_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ],
      "description": "TOTAL cumulative watch time across observed views, in milliseconds; never average watch duration."
    },
    "avg_watch_pct": {
      "anyOf": [
        {
          "type": "number",
          "minimum": 0,
          "maximum": 100
        },
        {
          "type": "null"
        }
      ]
    },
    "evidence_method": {
      "$ref": "#/components/schemas/AnalyticsEvidenceMethod"
    },
    "evidence_upload_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "average_watch_duration_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "description": "Average watch duration per view when explicitly supplied by authoritative evidence; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "completed_views": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "description": "Authoritatively supplied count of completed views; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "completion_rate_ppm": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000000,
          "description": "Completion ratio in parts-per-million; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "follower_delta": {
      "anyOf": [
        {
          "type": "integer",
          "description": "Net follower change attributable to the platform observation window when supplied; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "post_id",
    "checkin_id",
    "observed_at",
    "views",
    "qualified_views",
    "likes",
    "comments",
    "shares",
    "saves",
    "watch_time_ms",
    "average_watch_duration_ms",
    "completed_views",
    "completion_rate_ppm",
    "follower_delta",
    "avg_watch_pct",
    "evidence_method",
    "evidence_upload_id"
  ]
}
```

### Responses
- `201` Observation
```json
{
  "$ref": "#/components/schemas/AnalyticsCheckinResult"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "observation": {
      "$ref": "#/components/schemas/AnalyticsObservation"
    },
    "checkin": {
      "anyOf": [
        {
          "$ref": "#/components/schemas/AnalyticsCheckin"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "observation",
    "checkin"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_recordAnalyticsCheckin_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_recordAnalyticsCheckin_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_recordAnalyticsCheckin_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_recordAnalyticsCheckin_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_recordAnalyticsCheckin_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_recordAnalyticsCheckin_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "CONFLICT",
    "IDEMPOTENCY_KEY_REUSED",
    "INVALID_STATE_TRANSITION"
  ]
}
```

## `GET /v1/analytics/due` — `listDueAnalytics`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "limit",
    "in": "query",
    "required": false,
    "schema": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100,
      "default": 25
    }
  },
  {
    "name": "cursor",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "minLength": 1
    }
  },
  {
    "name": "status",
    "in": "query",
    "required": false,
    "schema": {
      "$ref": "#/components/schemas/CheckinStatus"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Due check-ins
```json
{
  "$ref": "#/components/schemas/AnalyticsDueList"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/AnalyticsCheckin"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_listDueAnalytics_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_listDueAnalytics_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_listDueAnalytics_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_listDueAnalytics_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `POST /v1/payout-events` — `recordPayoutEvent`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/PayoutEventRequest"
}
```
Resolved canonical request schema:
```json
{
  "oneOf": [
    {
      "$ref": "#/components/schemas/PayoutCreateEvent"
    },
    {
      "$ref": "#/components/schemas/PayoutTransitionEvent"
    }
  ],
  "discriminator": {
    "propertyName": "event_kind",
    "mapping": {
      "CREATE": "#/components/schemas/PayoutCreateEvent",
      "TRANSITION": "#/components/schemas/PayoutTransitionEvent"
    }
  }
}
```

### Responses
- `201` Earning
```json
{
  "$ref": "#/components/schemas/EarningRecord"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "external_earning_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "amount_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "state": {
      "$ref": "#/components/schemas/EarningState"
    },
    "recognized_at": {
      "type": "string",
      "format": "date-time"
    },
    "last_state_at": {
      "type": "string",
      "format": "date-time"
    },
    "source": {
      "type": "string",
      "enum": [
        "OWNER_MANUAL",
        "OFFICIAL_API",
        "COMPLIANT_IMPORT"
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "campaign_id",
    "post_id",
    "external_earning_id",
    "amount_usd",
    "state",
    "recognized_at",
    "last_state_at",
    "source"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_recordPayoutEvent_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_recordPayoutEvent_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_recordPayoutEvent_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "EARNING_ALREADY_EXISTS",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_recordPayoutEvent_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_recordPayoutEvent_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_recordPayoutEvent_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "CONFLICT",
    "EARNING_ALREADY_EXISTS",
    "IDEMPOTENCY_KEY_REUSED",
    "INVALID_STATE_TRANSITION"
  ]
}
```

## `GET /v1/finance/summary` — `getFinanceSummary`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "as_of",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "format": "date-time"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Finance summary
```json
{
  "$ref": "#/components/schemas/FinanceSummary"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "as_of": {
      "type": "string",
      "format": "date-time"
    },
    "currency": {
      "type": "string",
      "const": "USD"
    },
    "accrued_unverified_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "approved_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "withdrawable_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "withdrawn_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "gross_campaign_revenue_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "infrastructure_api_spend_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "polli_voice_reasoning_spend_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "lifetime_revenue_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "lifetime_spend_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "net_profit_usd": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^-?(0|[1-9][0-9]*)\\.[0-9]{6}$"
        },
        {
          "type": "null"
        }
      ],
      "description": "Null when material cost data is incomplete; never substituted with zero."
    },
    "monthly_target_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "monthly_target_progress_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "net_profit_truth_state": {
      "type": "string",
      "enum": [
        "FACT",
        "INCOMPLETE_UNKNOWN"
      ],
      "description": "FACT only when net_profit_usd is present and material cost data is sufficiently complete; INCOMPLETE_UNKNOWN requires net_profit_usd=null."
    },
    "self_funded_state": {
      "type": "string",
      "enum": [
        "FACTORY_SELF_FUNDED",
        "NOT_SELF_FUNDED",
        "UNKNOWN_NOT_VERIFIED"
      ],
      "description": "Canonical tri-state. UNKNOWN_NOT_VERIFIED is required when material revenue/cost evidence is incomplete; it must not be collapsed to false."
    }
  },
  "additionalProperties": false,
  "required": [
    "as_of",
    "currency",
    "accrued_unverified_usd",
    "approved_usd",
    "withdrawable_usd",
    "withdrawn_usd",
    "gross_campaign_revenue_usd",
    "infrastructure_api_spend_usd",
    "polli_voice_reasoning_spend_usd",
    "lifetime_revenue_usd",
    "lifetime_spend_usd",
    "net_profit_usd",
    "monthly_target_usd",
    "monthly_target_progress_usd",
    "net_profit_truth_state",
    "self_funded_state"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_getFinanceSummary_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_getFinanceSummary_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_getFinanceSummary_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_getFinanceSummary_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `GET /v1/costs/summary` — `getCostSummary`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "month",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}$"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Cost summary
```json
{
  "$ref": "#/components/schemas/CostSummary"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "as_of": {
      "type": "string",
      "format": "date-time"
    },
    "month": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}$"
    },
    "cash_spend_counted_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "unpaid_committed_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "admitted_queued_unfunded_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "prepaid_funding_purchased_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "prepaid_credit_remaining_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "governor_exposure_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "projected_month_end_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "remaining_hard_cap_usd": {
      "type": "string",
      "pattern": "^-?(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact USD decimal string with six fractional digits; never a JSON number."
    },
    "hard_cap_usd": {
      "type": "string",
      "const": "56.030000"
    },
    "optional_pause_usd": {
      "type": "string",
      "const": "43.000000"
    },
    "reserve_mode_usd": {
      "type": "string",
      "const": "51.030000"
    },
    "governor_state": {
      "type": "string",
      "enum": [
        "NORMAL",
        "OPTIONAL_PAUSED",
        "RESERVE",
        "HARD_STOP"
      ]
    },
    "groups": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/CostGroup"
      },
      "minItems": 0,
      "maxItems": 100
    }
  },
  "additionalProperties": false,
  "required": [
    "as_of",
    "month",
    "cash_spend_counted_usd",
    "unpaid_committed_usd",
    "admitted_queued_unfunded_usd",
    "prepaid_funding_purchased_usd",
    "prepaid_credit_remaining_usd",
    "governor_exposure_usd",
    "projected_month_end_usd",
    "remaining_hard_cap_usd",
    "hard_cap_usd",
    "optional_pause_usd",
    "reserve_mode_usd",
    "governor_state",
    "groups"
  ],
  "description": "Deterministic Month-1 cost governor snapshot. governor_exposure_usd = cash_spend_counted_usd + unpaid_committed_usd + admitted_queued_unfunded_usd using exact decimal arithmetic. NORMAL is exposure <43.000000; OPTIONAL_PAUSED is >=43.000000 and <51.030000; RESERVE is >=51.030000 and <56.030000; HARD_STOP is >=56.030000. No new optional paid work may be admitted when exposure is >=43.000000. Every paid action is evaluated against post-admission exposure before dispatch. Prepaid funding is counted in full at purchase in cash_spend_counted_usd; later usage of that already-counted credit is not double-counted. projected_month_end_usd is informational and can never loosen admission. HONOR_COST_GOVERNOR.json is authoritative."
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_getCostSummary_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_getCostSummary_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_getCostSummary_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `POST /v1/polli/sessions` — `startPolliSession`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/PolliSessionCreateRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "mode": {
      "$ref": "#/components/schemas/PolliMode"
    },
    "retention_mode": {
      "type": "string",
      "const": "TRANSCRIPT_SUMMARY"
    }
  },
  "additionalProperties": false,
  "required": [
    "mode",
    "retention_mode"
  ]
}
```

### Responses
- `201` Session
```json
{
  "$ref": "#/components/schemas/PolliSession"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "mode": {
      "$ref": "#/components/schemas/PolliMode"
    },
    "status": {
      "$ref": "#/components/schemas/PolliSessionStatus"
    },
    "started_at": {
      "type": "string",
      "format": "date-time"
    },
    "ended_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "backend_model_route": {
      "type": "string"
    },
    "estimated_cost_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "actual_cost_usd": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
          "description": "Exact USD decimal with six fractional digits; never a JSON number."
        },
        {
          "type": "null"
        }
      ]
    },
    "retention_mode": {
      "type": "string",
      "const": "TRANSCRIPT_SUMMARY"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "mode",
    "status",
    "started_at",
    "ended_at",
    "backend_model_route",
    "estimated_cost_usd",
    "actual_cost_usd",
    "retention_mode"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_startPolliSession_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_startPolliSession_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_startPolliSession_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_startPolliSession_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_startPolliSession_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_startPolliSession_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "COST_GOVERNOR_BLOCKED",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "IDEMPOTENCY_KEY_REUSED"
  ]
}
```

## `POST /v1/polli/live/sessions` — `createPolliLiveSession`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/PolliLiveSessionRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "polli_session_id": {
      "type": "string",
      "format": "uuid"
    },
    "sdp_offer": {
      "type": "string",
      "minLength": 1,
      "maxLength": 200000
    }
  },
  "additionalProperties": false,
  "required": [
    "polli_session_id",
    "sdp_offer"
  ]
}
```

### Responses
- `201` SDP answer
```json
{
  "$ref": "#/components/schemas/PolliLiveSessionResponse"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "polli_session_id": {
      "type": "string",
      "format": "uuid"
    },
    "live_session_ref": {
      "type": "string",
      "minLength": 1
    },
    "sdp_answer": {
      "type": "string",
      "minLength": 1
    },
    "expires_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "polli_session_id",
    "live_session_ref",
    "sdp_answer",
    "expires_at"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_createPolliLiveSession_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_createPolliLiveSession_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_createPolliLiveSession_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "SESSION_NOT_ACTIVE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_createPolliLiveSession_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_createPolliLiveSession_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_createPolliLiveSession_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "COST_GOVERNOR_BLOCKED",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "IDEMPOTENCY_KEY_REUSED",
    "SESSION_NOT_ACTIVE"
  ]
}
```

## `POST /v1/polli/query` — `queryPolli`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/PolliQueryRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {
    "session_id": {
      "type": "string",
      "format": "uuid"
    },
    "question": {
      "type": "string",
      "minLength": 1,
      "maxLength": 8000
    }
  },
  "additionalProperties": false,
  "required": [
    "session_id",
    "question"
  ]
}
```

### Responses
- `200` Polli answer
```json
{
  "$ref": "#/components/schemas/PolliQueryResponse"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "session_id": {
      "type": "string",
      "format": "uuid"
    },
    "answer": {
      "type": "string"
    },
    "label": {
      "$ref": "#/components/schemas/TruthLabel"
    },
    "claims": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/PolliClaim"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "tool_calls": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/PolliToolCallSummary"
      },
      "minItems": 0,
      "maxItems": 50
    },
    "as_of": {
      "type": "string",
      "format": "date-time"
    },
    "cost_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    }
  },
  "additionalProperties": false,
  "required": [
    "session_id",
    "answer",
    "label",
    "claims",
    "tool_calls",
    "as_of",
    "cost_usd"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_queryPolli_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_queryPolli_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_queryPolli_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "SESSION_NOT_ACTIVE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_queryPolli_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_queryPolli_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_queryPolli_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "COST_GOVERNOR_BLOCKED",
    "PROVIDER_UNAVAILABLE"
  ],
  "409": [
    "IDEMPOTENCY_KEY_REUSED",
    "SESSION_NOT_ACTIVE"
  ]
}
```

## `POST /v1/polli/sessions/{id}/end` — `endPolliSession`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  },
  {
    "name": "id",
    "in": "path",
    "required": true,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/PolliSessionEndRequest"
}
```
Resolved canonical request schema:
```json
{
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```

### Responses
- `200` Ended session
```json
{
  "$ref": "#/components/schemas/PolliSession"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "mode": {
      "$ref": "#/components/schemas/PolliMode"
    },
    "status": {
      "$ref": "#/components/schemas/PolliSessionStatus"
    },
    "started_at": {
      "type": "string",
      "format": "date-time"
    },
    "ended_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "backend_model_route": {
      "type": "string"
    },
    "estimated_cost_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "actual_cost_usd": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
          "description": "Exact USD decimal with six fractional digits; never a JSON number."
        },
        {
          "type": "null"
        }
      ]
    },
    "retention_mode": {
      "type": "string",
      "const": "TRANSCRIPT_SUMMARY"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "mode",
    "status",
    "started_at",
    "ended_at",
    "backend_model_route",
    "estimated_cost_usd",
    "actual_cost_usd",
    "retention_mode"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_endPolliSession_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_endPolliSession_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `404` Error
```json
{
  "$ref": "#/components/schemas/Error_endPolliSession_404"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_endPolliSession_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "SESSION_NOT_ACTIVE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_endPolliSession_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_endPolliSession_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_endPolliSession_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "404": [
    "NOT_FOUND"
  ],
  "409": [
    "IDEMPOTENCY_KEY_REUSED",
    "SESSION_NOT_ACTIVE"
  ]
}
```

## `GET /v1/owner-actions` — `listOwnerActions`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **NOT_REQUIRED**.

### Parameters
```json
[
  {
    "name": "limit",
    "in": "query",
    "required": false,
    "schema": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100,
      "default": 25
    }
  },
  {
    "name": "cursor",
    "in": "query",
    "required": false,
    "schema": {
      "type": "string",
      "minLength": 1
    }
  },
  {
    "name": "status",
    "in": "query",
    "required": false,
    "schema": {
      "$ref": "#/components/schemas/OwnerActionStatus"
    }
  }
]
```

### Request body
No JSON request body.

### Responses
- `200` Owner actions
```json
{
  "$ref": "#/components/schemas/OwnerActionList"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/OwnerAction"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_listOwnerActions_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_listOwnerActions_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_listOwnerActions_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_listOwnerActions_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "VALIDATION_ERROR"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ]
}
```

## `POST /v1/owner-actions/{id}/resolve` — `resolveOwnerAction`
Authorization: **OWNER_JWT_VIA_BFF**. Idempotency: **REQUIRED**.

### Parameters
```json
[
  {
    "name": "Idempotency-Key",
    "in": "header",
    "required": true,
    "schema": {
      "type": "string",
      "minLength": 8,
      "maxLength": 200
    },
    "description": "Required for every mutating V1 FastAPI operation."
  },
  {
    "name": "id",
    "in": "path",
    "required": true,
    "schema": {
      "type": "string",
      "format": "uuid"
    }
  }
]
```

### Request body
```json
{
  "$ref": "#/components/schemas/OwnerActionResolveRequest"
}
```
Resolved canonical request schema:
```json
{
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "const": "RESOLVED"
        },
        "resolution": {
          "oneOf": [
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "CAMPAIGN_RULE"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "CONFIRM_VALUE",
                    "MARK_UNKNOWN",
                    "MARK_NOT_APPLICABLE"
                  ]
                },
                "rule_key": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 200
                },
                "typed_value": {
                  "anyOf": [
                    {
                      "oneOf": [
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "STRING"
                            },
                            "value": {
                              "type": "string",
                              "maxLength": 200000
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "STRING_ARRAY"
                            },
                            "value": {
                              "type": "array",
                              "items": {
                                "type": "string",
                                "maxLength": 500
                              },
                              "minItems": 0,
                              "maxItems": 200,
                              "uniqueItems": true
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "INTEGER"
                            },
                            "value": {
                              "type": "integer"
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "BOOLEAN"
                            },
                            "value": {
                              "type": "boolean"
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "MONEY_USD"
                            },
                            "value": {
                              "type": "string",
                              "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
                              "description": "Exact non-negative USD decimal string with six fractional digits."
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "TIMESTAMP"
                            },
                            "value": {
                              "type": "string",
                              "format": "date-time"
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "DURATION_SECONDS"
                            },
                            "value": {
                              "type": "number",
                              "minimum": 0,
                              "maximum": 86400
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "PLATFORMS"
                            },
                            "value": {
                              "type": "array",
                              "items": {
                                "type": "string",
                                "enum": [
                                  "TIKTOK",
                                  "INSTAGRAM_REELS",
                                  "YOUTUBE_SHORTS"
                                ]
                              },
                              "minItems": 0,
                              "maxItems": 3,
                              "uniqueItems": true
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "REGIONS"
                            },
                            "value": {
                              "type": "array",
                              "items": {
                                "type": "string",
                                "pattern": "^[A-Z]{2}(-[A-Z0-9]{1,3})?$"
                              },
                              "minItems": 0,
                              "maxItems": 250,
                              "uniqueItems": true
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "RATE"
                            },
                            "value": {
                              "type": "object",
                              "properties": {
                                "amount": {
                                  "type": "string",
                                  "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
                                  "description": "Exact non-negative USD decimal string with six fractional digits."
                                },
                                "basis": {
                                  "type": "string",
                                  "enum": [
                                    "FLAT",
                                    "PER_1000_VIEWS",
                                    "PER_QUALIFIED_ACTION",
                                    "OTHER"
                                  ]
                                },
                                "unit_description": {
                                  "anyOf": [
                                    {
                                      "type": "string",
                                      "maxLength": 500
                                    },
                                    {
                                      "type": "null"
                                    }
                                  ]
                                }
                              },
                              "additionalProperties": false,
                              "required": [
                                "amount",
                                "basis",
                                "unit_description"
                              ]
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        }
                      ]
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "evidence_upload_id": {
                  "anyOf": [
                    {
                      "type": "string",
                      "format": "uuid"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "rule_key",
                "typed_value",
                "evidence_upload_id",
                "note"
              ]
            },
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "SOURCE_RIGHTS"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "AUTHORIZED",
                    "NOT_AUTHORIZED",
                    "UNKNOWN"
                  ]
                },
                "source_id": {
                  "type": "string",
                  "format": "uuid"
                },
                "evidence_upload_id": {
                  "anyOf": [
                    {
                      "type": "string",
                      "format": "uuid"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "source_id",
                "evidence_upload_id",
                "note"
              ]
            },
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "PROVIDER_SETUP"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "COMPLETED",
                    "DEFERRED",
                    "BLOCKED"
                  ]
                },
                "provider": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 100
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "provider",
                "note"
              ]
            },
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "GENERIC_CONFIRMATION"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "CONFIRMED",
                    "DECLINED"
                  ]
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "note"
              ]
            }
          ]
        }
      },
      "additionalProperties": false,
      "required": [
        "status",
        "resolution"
      ]
    },
    {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "const": "CANCELLED"
        },
        "resolution": {
          "type": "object",
          "properties": {
            "resolution_type": {
              "const": "CANCELLED"
            },
            "reason": {
              "type": "string",
              "minLength": 1,
              "maxLength": 2000
            }
          },
          "additionalProperties": false,
          "required": [
            "resolution_type",
            "reason"
          ]
        }
      },
      "additionalProperties": false,
      "required": [
        "status",
        "resolution"
      ]
    }
  ]
}
```

### Responses
- `200` Owner action
```json
{
  "$ref": "#/components/schemas/OwnerAction"
}
```
Resolved schema:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "action_type": {
      "type": "string",
      "enum": [
        "CAMPAIGN_RULE",
        "SOURCE_RIGHTS",
        "PROVIDER_SETUP",
        "GENERIC_CONFIRMATION"
      ]
    },
    "title": {
      "type": "string"
    },
    "reason": {
      "type": "string"
    },
    "entity_type": {
      "type": "string"
    },
    "entity_id": {
      "type": "string",
      "format": "uuid"
    },
    "status": {
      "$ref": "#/components/schemas/OwnerActionStatus"
    },
    "requested_at": {
      "type": "string",
      "format": "date-time"
    },
    "resolved_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "resolution": {
      "anyOf": [
        {
          "$ref": "#/components/schemas/OwnerActionResolutionV1"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "action_type",
    "title",
    "reason",
    "entity_type",
    "entity_id",
    "status",
    "requested_at",
    "resolved_at",
    "resolution"
  ]
}
```
- `401` Error
```json
{
  "$ref": "#/components/schemas/Error_resolveOwnerAction_401"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `403` Error
```json
{
  "$ref": "#/components/schemas/Error_resolveOwnerAction_403"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `404` Error
```json
{
  "$ref": "#/components/schemas/Error_resolveOwnerAction_404"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `409` Error
```json
{
  "$ref": "#/components/schemas/Error_resolveOwnerAction_409"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `422` Error
```json
{
  "$ref": "#/components/schemas/Error_resolveOwnerAction_422"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `429` Error
```json
{
  "$ref": "#/components/schemas/Error_resolveOwnerAction_429"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```
- `503` Error
```json
{
  "$ref": "#/components/schemas/Error_resolveOwnerAction_503"
}
```
Resolved schema:
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### Exact error codes
```json
{
  "401": [
    "AUTH_INVALID",
    "AUTH_REQUIRED"
  ],
  "403": [
    "OWNER_FORBIDDEN"
  ],
  "422": [
    "IDEMPOTENCY_KEY_REQUIRED",
    "VALIDATION_ERROR"
  ],
  "429": [
    "RATE_LIMITED"
  ],
  "503": [
    "AUTH_PROVIDER_UNAVAILABLE",
    "PROVIDER_UNAVAILABLE"
  ],
  "404": [
    "NOT_FOUND"
  ],
  "409": [
    "IDEMPOTENCY_KEY_REUSED",
    "INVALID_STATE_TRANSITION"
  ]
}
```

## Component schemas (machine-generated)

### `JobState`
```json
{
  "type": "string",
  "enum": [
    "queued",
    "running",
    "retrying",
    "blocked-owner-action",
    "failed-terminal",
    "succeeded",
    "cancelled"
  ]
}
```

### `CampaignStatus`
```json
{
  "type": "string",
  "enum": [
    "DISCOVERED",
    "VERIFYING",
    "ACTIVE",
    "PAUSED",
    "ENDED",
    "REJECTED",
    "UNKNOWN"
  ]
}
```

### `Platform`
```json
{
  "type": "string",
  "enum": [
    "TIKTOK",
    "INSTAGRAM_REELS",
    "YOUTUBE_SHORTS"
  ]
}
```

### `SourceOrigin`
```json
{
  "type": "string",
  "enum": [
    "CAMPAIGN_AUTHORIZED",
    "OWNER_OWNED",
    "EXPLICITLY_LICENSED"
  ]
}
```

### `SourceIngestStatus`
```json
{
  "type": "string",
  "enum": [
    "PENDING_UPLOAD",
    "QUEUED",
    "INGESTING",
    "READY",
    "BLOCKED_RIGHTS",
    "FAILED"
  ]
}
```

### `SourceEligibility`
```json
{
  "type": "string",
  "enum": [
    "ELIGIBLE",
    "INELIGIBLE",
    "UNKNOWN"
  ]
}
```

### `ClipState`
```json
{
  "type": "string",
  "enum": [
    "PLANNED",
    "RENDERING",
    "QC",
    "READY",
    "EJECTED",
    "POSTED",
    "ARCHIVED"
  ]
}
```

### `PostStatus`
```json
{
  "type": "string",
  "enum": [
    "PUBLISHED",
    "INVALIDATED"
  ]
}
```

### `SubmissionStatus`
```json
{
  "type": "string",
  "enum": [
    "NOT_REQUIRED",
    "PENDING",
    "SUBMITTED",
    "ACCEPTED",
    "REJECTED",
    "UNKNOWN"
  ]
}
```

### `CheckinType`
```json
{
  "type": "string",
  "enum": [
    "H2",
    "H24",
    "H72",
    "FINAL",
    "CUSTOM"
  ]
}
```

### `CheckinStatus`
```json
{
  "type": "string",
  "enum": [
    "PENDING",
    "DUE",
    "COMPLETED",
    "MISSED",
    "NOT_APPLICABLE"
  ]
}
```

### `AnalyticsEvidenceMethod`
```json
{
  "type": "string",
  "enum": [
    "OWNER_MANUAL",
    "OFFICIAL_API",
    "COMPLIANT_IMPORT"
  ]
}
```

### `EarningState`
```json
{
  "type": "string",
  "enum": [
    "ACCRUED_UNVERIFIED",
    "APPROVED",
    "WITHDRAWABLE",
    "WITHDRAWN",
    "VOIDED"
  ]
}
```

### `CostCategory`
```json
{
  "type": "string",
  "enum": [
    "INFRASTRUCTURE",
    "AI_REASONING",
    "TRANSCRIPTION",
    "POLLI_VOICE",
    "STORAGE",
    "GPU",
    "MONITORING",
    "DOMAIN",
    "OTHER"
  ]
}
```

### `Confidence`
```json
{
  "type": "string",
  "enum": [
    "HIGH",
    "MEDIUM",
    "LOW"
  ]
}
```

### `PolliMode`
```json
{
  "type": "string",
  "enum": [
    "TEXT",
    "VOICE"
  ]
}
```

### `PolliSessionStatus`
```json
{
  "type": "string",
  "enum": [
    "ACTIVE",
    "ENDED",
    "FAILED"
  ]
}
```

### `OwnerActionStatus`
```json
{
  "type": "string",
  "enum": [
    "OPEN",
    "RESOLVED",
    "CANCELLED"
  ]
}
```

### `UploadPurpose`
```json
{
  "type": "string",
  "enum": [
    "SOURCE_MEDIA",
    "CAMPAIGN_TERMS_EVIDENCE",
    "SOURCE_RIGHTS_EVIDENCE",
    "SUBMISSION_EVIDENCE",
    "ANALYTICS_EVIDENCE"
  ]
}
```

### `UploadState`
```json
{
  "type": "string",
  "enum": [
    "INTENT_CREATED",
    "UPLOADED",
    "VERIFIED",
    "REJECTED",
    "EXPIRED"
  ]
}
```

### `TruthLabel`
```json
{
  "type": "string",
  "enum": [
    "FACT",
    "ESTIMATE",
    "MODEL_ANALYSIS",
    "UNKNOWN"
  ]
}
```

### `KnowledgeState`
```json
{
  "type": "string",
  "enum": [
    "KNOWN",
    "UNKNOWN",
    "NOT_APPLICABLE"
  ]
}
```

### `UUID`
```json
{
  "type": "string",
  "format": "uuid"
}
```

### `DateTime`
```json
{
  "type": "string",
  "format": "date-time"
}
```

### `Date`
```json
{
  "type": "string",
  "format": "date"
}
```

### `MoneyUSD`
```json
{
  "type": "string",
  "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
  "description": "Exact USD decimal with six fractional digits; never a JSON number."
}
```

### `Sha256`
```json
{
  "type": "string",
  "pattern": "^[a-f0-9]{64}$"
}
```

### `PageMeta`
```json
{
  "type": "object",
  "properties": {
    "next_cursor": {
      "anyOf": [
        {
          "type": "string",
          "minLength": 1
        },
        {
          "type": "null"
        }
      ]
    },
    "limit": {
      "type": "integer",
      "minimum": 1,
      "maximum": 100
    },
    "has_more": {
      "type": "boolean"
    }
  },
  "additionalProperties": false,
  "required": [
    "next_cursor",
    "limit",
    "has_more"
  ]
}
```

### `HealthResponse`
```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "const": "ok"
    },
    "service": {
      "type": "string",
      "const": "honor-api"
    },
    "time": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "status",
    "service",
    "time"
  ]
}
```

### `ReadinessResponse`
```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "enum": [
        "ready",
        "not_ready"
      ]
    },
    "time": {
      "type": "string",
      "format": "date-time"
    },
    "checks": {
      "type": "object",
      "properties": {
        "database": {
          "type": "string",
          "enum": [
            "ok",
            "error"
          ]
        },
        "redis": {
          "type": "string",
          "enum": [
            "ok",
            "error"
          ]
        },
        "r2": {
          "type": "string",
          "enum": [
            "ok",
            "error"
          ]
        }
      },
      "additionalProperties": false,
      "required": [
        "database",
        "redis",
        "r2"
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "status",
    "time",
    "checks"
  ]
}
```

### `GenerationRunCreateRequest`
```json
{
  "type": "object",
  "properties": {
    "target_date": {
      "type": "string",
      "format": "date"
    },
    "campaign_ids": {
      "type": "array",
      "items": {
        "type": "string",
        "format": "uuid"
      },
      "minItems": 0,
      "maxItems": 50
    },
    "social_account_ids": {
      "type": "array",
      "items": {
        "type": "string",
        "format": "uuid"
      },
      "minItems": 0,
      "maxItems": 20
    },
    "requested_constraints": {
      "$ref": "#/components/schemas/GenerationRequestedConstraintsV1"
    }
  },
  "additionalProperties": false,
  "required": [
    "target_date"
  ]
}
```

### `GenerationRun`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "target_date": {
      "type": "string",
      "format": "date"
    },
    "state": {
      "$ref": "#/components/schemas/JobState"
    },
    "stage": {
      "type": "string",
      "enum": [
        "campaign_import",
        "rules_normalization",
        "source_ingest",
        "rights_verification",
        "transcription",
        "candidate_discovery",
        "candidate_scoring",
        "finalist_selection",
        "edit_plan",
        "audio_plan",
        "render",
        "qc",
        "schedule",
        "analytics_ingest",
        "payout_reconcile",
        "cost_reconcile",
        "backup"
      ]
    },
    "strategy_version": {
      "type": "string"
    },
    "budget_snapshot": {
      "$ref": "jsonschema/generation.budget_snapshot.v1.json"
    },
    "requested_constraints": {
      "$ref": "jsonschema/generation.requested_constraints.v1.json"
    },
    "selected_plan": {
      "anyOf": [
        {
          "$ref": "jsonschema/generation.selected_plan.v1.json"
        },
        {
          "type": "null"
        }
      ]
    },
    "correlation_id": {
      "type": "string",
      "format": "uuid"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "completed_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "target_date",
    "state",
    "stage",
    "strategy_version",
    "budget_snapshot",
    "requested_constraints",
    "selected_plan",
    "correlation_id",
    "created_at",
    "completed_at"
  ]
}
```

### `CampaignRuleItem`
```json
{
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "provider"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "STRING"
                },
                "value": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 200
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "STRING"
                  },
                  "value": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 200
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `provider` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `provider`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "campaign_url"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "STRING"
                },
                "value": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 2000,
                  "format": "uri"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "STRING"
                  },
                  "value": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 2000,
                    "format": "uri"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `campaign_url` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `campaign_url`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "external_campaign_id"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "STRING"
                },
                "value": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 500
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "STRING"
                  },
                  "value": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 500
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `external_campaign_id` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `external_campaign_id`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "status"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "CAMPAIGN_STATUS"
                },
                "value": {
                  "type": "string",
                  "enum": [
                    "DISCOVERED",
                    "VERIFYING",
                    "ACTIVE",
                    "PAUSED",
                    "ENDED",
                    "REJECTED"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "CAMPAIGN_STATUS"
                  },
                  "value": {
                    "type": "string",
                    "enum": [
                      "DISCOVERED",
                      "VERIFYING",
                      "ACTIVE",
                      "PAUSED",
                      "ENDED",
                      "REJECTED"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `status` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `status`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "compensation_model"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "COMPENSATION_MODEL"
                },
                "value": {
                  "type": "string",
                  "enum": [
                    "CPM",
                    "FLAT_PER_CLIP",
                    "PER_QUALIFIED_ACTION",
                    "HYBRID",
                    "OTHER"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "COMPENSATION_MODEL"
                  },
                  "value": {
                    "type": "string",
                    "enum": [
                      "CPM",
                      "FLAT_PER_CLIP",
                      "PER_QUALIFIED_ACTION",
                      "HYBRID",
                      "OTHER"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `compensation_model` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `compensation_model`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "cpm_or_rate"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "RATE"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "amount": {
                      "type": "string",
                      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                    },
                    "basis": {
                      "type": "string",
                      "enum": [
                        "FLAT",
                        "PER_1000_VIEWS",
                        "PER_QUALIFIED_ACTION",
                        "OTHER"
                      ]
                    },
                    "unit_description": {
                      "anyOf": [
                        {
                          "type": "string",
                          "maxLength": 500
                        },
                        {
                          "type": "null"
                        }
                      ]
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "amount",
                    "basis",
                    "unit_description"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "RATE"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "amount": {
                        "type": "string",
                        "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                      },
                      "basis": {
                        "type": "string",
                        "enum": [
                          "FLAT",
                          "PER_1000_VIEWS",
                          "PER_QUALIFIED_ACTION",
                          "OTHER"
                        ]
                      },
                      "unit_description": {
                        "anyOf": [
                          {
                            "type": "string",
                            "maxLength": 500
                          },
                          {
                            "type": "null"
                          }
                        ]
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "amount",
                      "basis",
                      "unit_description"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `cpm_or_rate` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `cpm_or_rate`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "minimum_views"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "INTEGER"
                },
                "value": {
                  "type": "integer",
                  "minimum": 0
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "INTEGER"
                  },
                  "value": {
                    "type": "integer",
                    "minimum": 0
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `minimum_views` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `minimum_views`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "max_payout_per_clip"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "MONEY_USD"
                },
                "value": {
                  "type": "string",
                  "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "MONEY_USD"
                  },
                  "value": {
                    "type": "string",
                    "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `max_payout_per_clip` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `max_payout_per_clip`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "total_budget"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "MONEY_USD"
                },
                "value": {
                  "type": "string",
                  "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "MONEY_USD"
                  },
                  "value": {
                    "type": "string",
                    "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `total_budget` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `total_budget`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "remaining_budget"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "MONEY_USD"
                },
                "value": {
                  "type": "string",
                  "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "MONEY_USD"
                  },
                  "value": {
                    "type": "string",
                    "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `remaining_budget` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `remaining_budget`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "start_at"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "TIMESTAMP"
                },
                "value": {
                  "type": "string",
                  "format": "date-time"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "TIMESTAMP"
                  },
                  "value": {
                    "type": "string",
                    "format": "date-time"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `start_at` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `start_at`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "end_at"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "TIMESTAMP"
                },
                "value": {
                  "type": "string",
                  "format": "date-time"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "TIMESTAMP"
                  },
                  "value": {
                    "type": "string",
                    "format": "date-time"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `end_at` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `end_at`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "deadline_at"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "TIMESTAMP"
                },
                "value": {
                  "type": "string",
                  "format": "date-time"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "TIMESTAMP"
                  },
                  "value": {
                    "type": "string",
                    "format": "date-time"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `deadline_at` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `deadline_at`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "eligible_platforms"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "PLATFORMS"
                },
                "value": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "enum": [
                      "TIKTOK",
                      "INSTAGRAM_REELS",
                      "YOUTUBE_SHORTS"
                    ]
                  },
                  "minItems": 1,
                  "maxItems": 3,
                  "uniqueItems": true
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "PLATFORMS"
                  },
                  "value": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "enum": [
                        "TIKTOK",
                        "INSTAGRAM_REELS",
                        "YOUTUBE_SHORTS"
                      ]
                    },
                    "minItems": 1,
                    "maxItems": 3,
                    "uniqueItems": true
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `eligible_platforms` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `eligible_platforms`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "eligible_regions"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "REGIONS"
                },
                "value": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "pattern": "^[A-Z]{2}(-[A-Z0-9]{1,3})?$"
                  },
                  "minItems": 1,
                  "maxItems": 250,
                  "uniqueItems": true
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "REGIONS"
                  },
                  "value": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "pattern": "^[A-Z]{2}(-[A-Z0-9]{1,3})?$"
                    },
                    "minItems": 1,
                    "maxItems": 250,
                    "uniqueItems": true
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `eligible_regions` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `eligible_regions`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "eligible_account_requirements"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "ACCOUNT_REQUIREMENTS"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "min_followers": {
                      "anyOf": [
                        {
                          "type": "integer",
                          "minimum": 0
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "max_followers": {
                      "anyOf": [
                        {
                          "type": "integer",
                          "minimum": 0
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "require_posting_available": {
                      "type": "boolean"
                    },
                    "allowed_health_states": {
                      "type": "array",
                      "items": {
                        "type": "string",
                        "enum": [
                          "HEALTHY",
                          "CAUTION"
                        ]
                      },
                      "minItems": 1,
                      "maxItems": 2,
                      "uniqueItems": true
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "min_followers",
                    "max_followers",
                    "require_posting_available",
                    "allowed_health_states"
                  ],
                  "allOf": [
                    {
                      "if": {
                        "properties": {
                          "min_followers": {
                            "type": "integer"
                          },
                          "max_followers": {
                            "type": "integer"
                          }
                        },
                        "required": [
                          "min_followers",
                          "max_followers"
                        ]
                      },
                      "then": {
                        "properties": {}
                      }
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "ACCOUNT_REQUIREMENTS"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "min_followers": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "max_followers": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "require_posting_available": {
                        "type": "boolean"
                      },
                      "allowed_health_states": {
                        "type": "array",
                        "items": {
                          "type": "string",
                          "enum": [
                            "HEALTHY",
                            "CAUTION"
                          ]
                        },
                        "minItems": 1,
                        "maxItems": 2,
                        "uniqueItems": true
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "min_followers",
                      "max_followers",
                      "require_posting_available",
                      "allowed_health_states"
                    ],
                    "allOf": [
                      {
                        "if": {
                          "properties": {
                            "min_followers": {
                              "type": "integer"
                            },
                            "max_followers": {
                              "type": "integer"
                            }
                          },
                          "required": [
                            "min_followers",
                            "max_followers"
                          ]
                        },
                        "then": {
                          "properties": {}
                        }
                      }
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `eligible_account_requirements` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `eligible_account_requirements`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "required_tags"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "STRING_ARRAY"
                },
                "value": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 200
                  },
                  "minItems": 0,
                  "maxItems": 200,
                  "uniqueItems": true
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "STRING_ARRAY"
                  },
                  "value": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "minLength": 1,
                      "maxLength": 200
                    },
                    "minItems": 0,
                    "maxItems": 200,
                    "uniqueItems": true
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `required_tags` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `required_tags`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "required_mentions"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "STRING_ARRAY"
                },
                "value": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "pattern": "^@?[^\\s@]{1,199}$"
                  },
                  "minItems": 0,
                  "maxItems": 200,
                  "uniqueItems": true
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "STRING_ARRAY"
                  },
                  "value": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "pattern": "^@?[^\\s@]{1,199}$"
                    },
                    "minItems": 0,
                    "maxItems": 200,
                    "uniqueItems": true
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `required_mentions` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `required_mentions`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "required_hashtags"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "STRING_ARRAY"
                },
                "value": {
                  "type": "array",
                  "items": {
                    "type": "string",
                    "pattern": "^#[^\\s#]{1,99}$"
                  },
                  "minItems": 0,
                  "maxItems": 200,
                  "uniqueItems": true
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "STRING_ARRAY"
                  },
                  "value": {
                    "type": "array",
                    "items": {
                      "type": "string",
                      "pattern": "^#[^\\s#]{1,99}$"
                    },
                    "minItems": 0,
                    "maxItems": 200,
                    "uniqueItems": true
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `required_hashtags` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `required_hashtags`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "disclosure_requirements"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "DISCLOSURE_REQUIREMENTS"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "required": {
                      "type": "boolean"
                    },
                    "text": {
                      "anyOf": [
                        {
                          "type": "string",
                          "minLength": 1,
                          "maxLength": 2000
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "instructions": {
                      "type": "array",
                      "items": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 1000
                      },
                      "minItems": 0,
                      "maxItems": 20
                    },
                    "placement": {
                      "anyOf": [
                        {
                          "type": "string",
                          "enum": [
                            "CAPTION",
                            "VIDEO",
                            "BOTH",
                            "PROVIDER_SUBMISSION"
                          ]
                        },
                        {
                          "type": "null"
                        }
                      ]
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "required",
                    "text",
                    "instructions",
                    "placement"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "DISCLOSURE_REQUIREMENTS"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "required": {
                        "type": "boolean"
                      },
                      "text": {
                        "anyOf": [
                          {
                            "type": "string",
                            "minLength": 1,
                            "maxLength": 2000
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "instructions": {
                        "type": "array",
                        "items": {
                          "type": "string",
                          "minLength": 1,
                          "maxLength": 1000
                        },
                        "minItems": 0,
                        "maxItems": 20
                      },
                      "placement": {
                        "anyOf": [
                          {
                            "type": "string",
                            "enum": [
                              "CAPTION",
                              "VIDEO",
                              "BOTH",
                              "PROVIDER_SUBMISSION"
                            ]
                          },
                          {
                            "type": "null"
                          }
                        ]
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "required",
                      "text",
                      "instructions",
                      "placement"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `disclosure_requirements` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `disclosure_requirements`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "source_material_restrictions"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "RESTRICTION_SET"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "clauses": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "code": {
                            "type": "string",
                            "enum": [
                              "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                              "OWNER_OWNED_SOURCE_ONLY",
                              "NO_THIRD_PARTY_SOURCE",
                              "NO_PROFANITY",
                              "BRAND_SAFE_ONLY",
                              "NO_MISLEADING_CLAIMS",
                              "NO_CROP",
                              "NO_SPEED_CHANGE",
                              "NO_TEXT_OVERLAY",
                              "NO_REUSED_EDIT",
                              "UNIQUE_PER_ACCOUNT",
                              "UNIQUE_PER_CAMPAIGN"
                            ]
                          },
                          "effect": {
                            "type": "string",
                            "enum": [
                              "REQUIRE",
                              "PROHIBIT"
                            ]
                          },
                          "scope": {
                            "type": "string",
                            "enum": [
                              "SOURCE",
                              "CONTENT",
                              "EDIT",
                              "UNIQUENESS"
                            ]
                          }
                        },
                        "additionalProperties": false,
                        "required": [
                          "code",
                          "effect",
                          "scope"
                        ]
                      },
                      "minItems": 0,
                      "maxItems": 50,
                      "uniqueItems": true
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "clauses"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "RESTRICTION_SET"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "clauses": {
                        "type": "array",
                        "items": {
                          "type": "object",
                          "properties": {
                            "code": {
                              "type": "string",
                              "enum": [
                                "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                                "OWNER_OWNED_SOURCE_ONLY",
                                "NO_THIRD_PARTY_SOURCE",
                                "NO_PROFANITY",
                                "BRAND_SAFE_ONLY",
                                "NO_MISLEADING_CLAIMS",
                                "NO_CROP",
                                "NO_SPEED_CHANGE",
                                "NO_TEXT_OVERLAY",
                                "NO_REUSED_EDIT",
                                "UNIQUE_PER_ACCOUNT",
                                "UNIQUE_PER_CAMPAIGN"
                              ]
                            },
                            "effect": {
                              "type": "string",
                              "enum": [
                                "REQUIRE",
                                "PROHIBIT"
                              ]
                            },
                            "scope": {
                              "type": "string",
                              "enum": [
                                "SOURCE",
                                "CONTENT",
                                "EDIT",
                                "UNIQUENESS"
                              ]
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "code",
                            "effect",
                            "scope"
                          ]
                        },
                        "minItems": 0,
                        "maxItems": 50,
                        "uniqueItems": true
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "clauses"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `source_material_restrictions` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `source_material_restrictions`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "clip_length_min_seconds"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "DURATION_SECONDS"
                },
                "value": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 600
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "DURATION_SECONDS"
                  },
                  "value": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 600
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `clip_length_min_seconds` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `clip_length_min_seconds`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "clip_length_max_seconds"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "DURATION_SECONDS"
                },
                "value": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 600
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "DURATION_SECONDS"
                  },
                  "value": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 600
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `clip_length_max_seconds` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `clip_length_max_seconds`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "content_restrictions"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "RESTRICTION_SET"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "clauses": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "code": {
                            "type": "string",
                            "enum": [
                              "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                              "OWNER_OWNED_SOURCE_ONLY",
                              "NO_THIRD_PARTY_SOURCE",
                              "NO_PROFANITY",
                              "BRAND_SAFE_ONLY",
                              "NO_MISLEADING_CLAIMS",
                              "NO_CROP",
                              "NO_SPEED_CHANGE",
                              "NO_TEXT_OVERLAY",
                              "NO_REUSED_EDIT",
                              "UNIQUE_PER_ACCOUNT",
                              "UNIQUE_PER_CAMPAIGN"
                            ]
                          },
                          "effect": {
                            "type": "string",
                            "enum": [
                              "REQUIRE",
                              "PROHIBIT"
                            ]
                          },
                          "scope": {
                            "type": "string",
                            "enum": [
                              "SOURCE",
                              "CONTENT",
                              "EDIT",
                              "UNIQUENESS"
                            ]
                          }
                        },
                        "additionalProperties": false,
                        "required": [
                          "code",
                          "effect",
                          "scope"
                        ]
                      },
                      "minItems": 0,
                      "maxItems": 50,
                      "uniqueItems": true
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "clauses"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "RESTRICTION_SET"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "clauses": {
                        "type": "array",
                        "items": {
                          "type": "object",
                          "properties": {
                            "code": {
                              "type": "string",
                              "enum": [
                                "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                                "OWNER_OWNED_SOURCE_ONLY",
                                "NO_THIRD_PARTY_SOURCE",
                                "NO_PROFANITY",
                                "BRAND_SAFE_ONLY",
                                "NO_MISLEADING_CLAIMS",
                                "NO_CROP",
                                "NO_SPEED_CHANGE",
                                "NO_TEXT_OVERLAY",
                                "NO_REUSED_EDIT",
                                "UNIQUE_PER_ACCOUNT",
                                "UNIQUE_PER_CAMPAIGN"
                              ]
                            },
                            "effect": {
                              "type": "string",
                              "enum": [
                                "REQUIRE",
                                "PROHIBIT"
                              ]
                            },
                            "scope": {
                              "type": "string",
                              "enum": [
                                "SOURCE",
                                "CONTENT",
                                "EDIT",
                                "UNIQUENESS"
                              ]
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "code",
                            "effect",
                            "scope"
                          ]
                        },
                        "minItems": 0,
                        "maxItems": 50,
                        "uniqueItems": true
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "clauses"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `content_restrictions` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `content_restrictions`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "editing_restrictions"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "RESTRICTION_SET"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "clauses": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "code": {
                            "type": "string",
                            "enum": [
                              "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                              "OWNER_OWNED_SOURCE_ONLY",
                              "NO_THIRD_PARTY_SOURCE",
                              "NO_PROFANITY",
                              "BRAND_SAFE_ONLY",
                              "NO_MISLEADING_CLAIMS",
                              "NO_CROP",
                              "NO_SPEED_CHANGE",
                              "NO_TEXT_OVERLAY",
                              "NO_REUSED_EDIT",
                              "UNIQUE_PER_ACCOUNT",
                              "UNIQUE_PER_CAMPAIGN"
                            ]
                          },
                          "effect": {
                            "type": "string",
                            "enum": [
                              "REQUIRE",
                              "PROHIBIT"
                            ]
                          },
                          "scope": {
                            "type": "string",
                            "enum": [
                              "SOURCE",
                              "CONTENT",
                              "EDIT",
                              "UNIQUENESS"
                            ]
                          }
                        },
                        "additionalProperties": false,
                        "required": [
                          "code",
                          "effect",
                          "scope"
                        ]
                      },
                      "minItems": 0,
                      "maxItems": 50,
                      "uniqueItems": true
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "clauses"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "RESTRICTION_SET"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "clauses": {
                        "type": "array",
                        "items": {
                          "type": "object",
                          "properties": {
                            "code": {
                              "type": "string",
                              "enum": [
                                "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                                "OWNER_OWNED_SOURCE_ONLY",
                                "NO_THIRD_PARTY_SOURCE",
                                "NO_PROFANITY",
                                "BRAND_SAFE_ONLY",
                                "NO_MISLEADING_CLAIMS",
                                "NO_CROP",
                                "NO_SPEED_CHANGE",
                                "NO_TEXT_OVERLAY",
                                "NO_REUSED_EDIT",
                                "UNIQUE_PER_ACCOUNT",
                                "UNIQUE_PER_CAMPAIGN"
                              ]
                            },
                            "effect": {
                              "type": "string",
                              "enum": [
                                "REQUIRE",
                                "PROHIBIT"
                              ]
                            },
                            "scope": {
                              "type": "string",
                              "enum": [
                                "SOURCE",
                                "CONTENT",
                                "EDIT",
                                "UNIQUENESS"
                              ]
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "code",
                            "effect",
                            "scope"
                          ]
                        },
                        "minItems": 0,
                        "maxItems": 50,
                        "uniqueItems": true
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "clauses"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `editing_restrictions` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `editing_restrictions`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "uniqueness_rules"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "RESTRICTION_SET"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "clauses": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "code": {
                            "type": "string",
                            "enum": [
                              "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                              "OWNER_OWNED_SOURCE_ONLY",
                              "NO_THIRD_PARTY_SOURCE",
                              "NO_PROFANITY",
                              "BRAND_SAFE_ONLY",
                              "NO_MISLEADING_CLAIMS",
                              "NO_CROP",
                              "NO_SPEED_CHANGE",
                              "NO_TEXT_OVERLAY",
                              "NO_REUSED_EDIT",
                              "UNIQUE_PER_ACCOUNT",
                              "UNIQUE_PER_CAMPAIGN"
                            ]
                          },
                          "effect": {
                            "type": "string",
                            "enum": [
                              "REQUIRE",
                              "PROHIBIT"
                            ]
                          },
                          "scope": {
                            "type": "string",
                            "enum": [
                              "SOURCE",
                              "CONTENT",
                              "EDIT",
                              "UNIQUENESS"
                            ]
                          }
                        },
                        "additionalProperties": false,
                        "required": [
                          "code",
                          "effect",
                          "scope"
                        ]
                      },
                      "minItems": 0,
                      "maxItems": 50,
                      "uniqueItems": true
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "clauses"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "RESTRICTION_SET"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "clauses": {
                        "type": "array",
                        "items": {
                          "type": "object",
                          "properties": {
                            "code": {
                              "type": "string",
                              "enum": [
                                "CAMPAIGN_AUTHORIZED_SOURCE_ONLY",
                                "OWNER_OWNED_SOURCE_ONLY",
                                "NO_THIRD_PARTY_SOURCE",
                                "NO_PROFANITY",
                                "BRAND_SAFE_ONLY",
                                "NO_MISLEADING_CLAIMS",
                                "NO_CROP",
                                "NO_SPEED_CHANGE",
                                "NO_TEXT_OVERLAY",
                                "NO_REUSED_EDIT",
                                "UNIQUE_PER_ACCOUNT",
                                "UNIQUE_PER_CAMPAIGN"
                              ]
                            },
                            "effect": {
                              "type": "string",
                              "enum": [
                                "REQUIRE",
                                "PROHIBIT"
                              ]
                            },
                            "scope": {
                              "type": "string",
                              "enum": [
                                "SOURCE",
                                "CONTENT",
                                "EDIT",
                                "UNIQUENESS"
                              ]
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "code",
                            "effect",
                            "scope"
                          ]
                        },
                        "minItems": 0,
                        "maxItems": 50,
                        "uniqueItems": true
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "clauses"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `uniqueness_rules` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `uniqueness_rules`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "submission_format"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "SUBMISSION_FORMAT"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "required": {
                      "type": "boolean"
                    },
                    "instructions": {
                      "type": "array",
                      "items": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 1500
                      },
                      "minItems": 0,
                      "maxItems": 30
                    },
                    "submission_url": {
                      "anyOf": [
                        {
                          "type": "string",
                          "format": "uri"
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "required_evidence": {
                      "type": "array",
                      "items": {
                        "type": "string",
                        "enum": [
                          "POST_URL",
                          "PLATFORM_POST_ID",
                          "SCREENSHOT",
                          "ANALYTICS_SNAPSHOT",
                          "OTHER"
                        ]
                      },
                      "minItems": 0,
                      "maxItems": 5,
                      "uniqueItems": true
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "required",
                    "instructions",
                    "submission_url",
                    "required_evidence"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "SUBMISSION_FORMAT"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "required": {
                        "type": "boolean"
                      },
                      "instructions": {
                        "type": "array",
                        "items": {
                          "type": "string",
                          "minLength": 1,
                          "maxLength": 1500
                        },
                        "minItems": 0,
                        "maxItems": 30
                      },
                      "submission_url": {
                        "anyOf": [
                          {
                            "type": "string",
                            "format": "uri"
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "required_evidence": {
                        "type": "array",
                        "items": {
                          "type": "string",
                          "enum": [
                            "POST_URL",
                            "PLATFORM_POST_ID",
                            "SCREENSHOT",
                            "ANALYTICS_SNAPSHOT",
                            "OTHER"
                          ]
                        },
                        "minItems": 0,
                        "maxItems": 5,
                        "uniqueItems": true
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "required",
                      "instructions",
                      "submission_url",
                      "required_evidence"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `submission_format` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `submission_format`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "analytics_window"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "WINDOW"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "start_offset_minutes": {
                      "anyOf": [
                        {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 525600
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "end_offset_minutes": {
                      "anyOf": [
                        {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 525600
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "description": {
                      "anyOf": [
                        {
                          "type": "string",
                          "maxLength": 1000
                        },
                        {
                          "type": "null"
                        }
                      ]
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "start_offset_minutes",
                    "end_offset_minutes",
                    "description"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "WINDOW"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "start_offset_minutes": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 525600
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "end_offset_minutes": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 525600
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "description": {
                        "anyOf": [
                          {
                            "type": "string",
                            "maxLength": 1000
                          },
                          {
                            "type": "null"
                          }
                        ]
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "start_offset_minutes",
                      "end_offset_minutes",
                      "description"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `analytics_window` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `analytics_window`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "payout_window"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "WINDOW"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "start_offset_minutes": {
                      "anyOf": [
                        {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 525600
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "end_offset_minutes": {
                      "anyOf": [
                        {
                          "type": "integer",
                          "minimum": 0,
                          "maximum": 525600
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "description": {
                      "anyOf": [
                        {
                          "type": "string",
                          "maxLength": 1000
                        },
                        {
                          "type": "null"
                        }
                      ]
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "start_offset_minutes",
                    "end_offset_minutes",
                    "description"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "WINDOW"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "start_offset_minutes": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 525600
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "end_offset_minutes": {
                        "anyOf": [
                          {
                            "type": "integer",
                            "minimum": 0,
                            "maximum": 525600
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "description": {
                        "anyOf": [
                          {
                            "type": "string",
                            "maxLength": 1000
                          },
                          {
                            "type": "null"
                          }
                        ]
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "start_offset_minutes",
                      "end_offset_minutes",
                      "description"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `payout_window` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `payout_window`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "render_audio_rules"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "RENDER_AUDIO_RULES"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "render_safe_audio": {
                      "type": "string",
                      "enum": [
                        "ALLOWED",
                        "PROHIBITED",
                        "UNKNOWN",
                        "NOT_APPLICABLE"
                      ]
                    },
                    "music_allowed": {
                      "type": "string",
                      "enum": [
                        "ALLOWED",
                        "PROHIBITED",
                        "UNKNOWN",
                        "NOT_APPLICABLE"
                      ]
                    },
                    "sfx_allowed": {
                      "type": "string",
                      "enum": [
                        "ALLOWED",
                        "PROHIBITED",
                        "UNKNOWN",
                        "NOT_APPLICABLE"
                      ]
                    },
                    "max_sfx_density": {
                      "anyOf": [
                        {
                          "type": "string",
                          "enum": [
                            "NONE",
                            "LOW",
                            "MEDIUM",
                            "HIGH"
                          ]
                        },
                        {
                          "type": "null"
                        }
                      ]
                    },
                    "instructions": {
                      "type": "array",
                      "items": {
                        "type": "string",
                        "minLength": 1,
                        "maxLength": 1000
                      },
                      "minItems": 0,
                      "maxItems": 20
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "render_safe_audio",
                    "music_allowed",
                    "sfx_allowed",
                    "max_sfx_density",
                    "instructions"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "RENDER_AUDIO_RULES"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "render_safe_audio": {
                        "type": "string",
                        "enum": [
                          "ALLOWED",
                          "PROHIBITED",
                          "UNKNOWN",
                          "NOT_APPLICABLE"
                        ]
                      },
                      "music_allowed": {
                        "type": "string",
                        "enum": [
                          "ALLOWED",
                          "PROHIBITED",
                          "UNKNOWN",
                          "NOT_APPLICABLE"
                        ]
                      },
                      "sfx_allowed": {
                        "type": "string",
                        "enum": [
                          "ALLOWED",
                          "PROHIBITED",
                          "UNKNOWN",
                          "NOT_APPLICABLE"
                        ]
                      },
                      "max_sfx_density": {
                        "anyOf": [
                          {
                            "type": "string",
                            "enum": [
                              "NONE",
                              "LOW",
                              "MEDIUM",
                              "HIGH"
                            ]
                          },
                          {
                            "type": "null"
                          }
                        ]
                      },
                      "instructions": {
                        "type": "array",
                        "items": {
                          "type": "string",
                          "minLength": 1,
                          "maxLength": 1000
                        },
                        "minItems": 0,
                        "maxItems": 20
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "render_safe_audio",
                      "music_allowed",
                      "sfx_allowed",
                      "max_sfx_density",
                      "instructions"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `render_audio_rules` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `render_audio_rules`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "platform_native_audio_rules"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "PLATFORM_NATIVE_AUDIO_RULES"
                },
                "value": {
                  "type": "object",
                  "properties": {
                    "TIKTOK": {
                      "type": "string",
                      "enum": [
                        "ALLOWED",
                        "PROHIBITED",
                        "UNKNOWN",
                        "NOT_APPLICABLE"
                      ]
                    },
                    "INSTAGRAM_REELS": {
                      "type": "string",
                      "enum": [
                        "ALLOWED",
                        "PROHIBITED",
                        "UNKNOWN",
                        "NOT_APPLICABLE"
                      ]
                    },
                    "YOUTUBE_SHORTS": {
                      "type": "string",
                      "enum": [
                        "ALLOWED",
                        "PROHIBITED",
                        "UNKNOWN",
                        "NOT_APPLICABLE"
                      ]
                    }
                  },
                  "additionalProperties": false,
                  "required": [
                    "TIKTOK",
                    "INSTAGRAM_REELS",
                    "YOUTUBE_SHORTS"
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "PLATFORM_NATIVE_AUDIO_RULES"
                  },
                  "value": {
                    "type": "object",
                    "properties": {
                      "TIKTOK": {
                        "type": "string",
                        "enum": [
                          "ALLOWED",
                          "PROHIBITED",
                          "UNKNOWN",
                          "NOT_APPLICABLE"
                        ]
                      },
                      "INSTAGRAM_REELS": {
                        "type": "string",
                        "enum": [
                          "ALLOWED",
                          "PROHIBITED",
                          "UNKNOWN",
                          "NOT_APPLICABLE"
                        ]
                      },
                      "YOUTUBE_SHORTS": {
                        "type": "string",
                        "enum": [
                          "ALLOWED",
                          "PROHIBITED",
                          "UNKNOWN",
                          "NOT_APPLICABLE"
                        ]
                      }
                    },
                    "additionalProperties": false,
                    "required": [
                      "TIKTOK",
                      "INSTAGRAM_REELS",
                      "YOUTUBE_SHORTS"
                    ]
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `platform_native_audio_rules` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `platform_native_audio_rules`."
    },
    {
      "type": "object",
      "properties": {
        "rule_snapshot_id": {
          "type": "string",
          "format": "uuid",
          "description": "Exact immutable campaign_terms_snapshots.id / normalized rule-set identity."
        },
        "rule_key": {
          "const": "last_verified_at"
        },
        "knowledge_state": {
          "$ref": "#/components/schemas/KnowledgeState"
        },
        "typed_value": {
          "anyOf": [
            {
              "type": "object",
              "properties": {
                "value_type": {
                  "const": "TIMESTAMP"
                },
                "value": {
                  "type": "string",
                  "format": "date-time"
                }
              },
              "additionalProperties": false,
              "required": [
                "value_type",
                "value"
              ]
            },
            {
              "type": "null"
            }
          ]
        },
        "confidence": {
          "anyOf": [
            {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_snapshot_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ]
        },
        "evidence_locator": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ]
        },
        "verified_by": {
          "type": "string",
          "enum": [
            "API",
            "IMPORTER",
            "OWNER",
            "BUILDER"
          ]
        },
        "schema_version": {
          "const": 1
        }
      },
      "required": [
        "rule_snapshot_id",
        "rule_key",
        "knowledge_state",
        "typed_value",
        "confidence",
        "evidence_snapshot_id",
        "evidence_locator",
        "verified_at",
        "verified_by",
        "schema_version"
      ],
      "additionalProperties": false,
      "allOf": [
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "KNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "object",
                "properties": {
                  "value_type": {
                    "const": "TIMESTAMP"
                  },
                  "value": {
                    "type": "string",
                    "format": "date-time"
                  }
                },
                "additionalProperties": false,
                "required": [
                  "value_type",
                  "value"
                ]
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "NOT_APPLICABLE"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              },
              "evidence_snapshot_id": {
                "type": "string",
                "format": "uuid"
              },
              "verified_at": {
                "type": "string",
                "format": "date-time"
              }
            },
            "required": [
              "typed_value",
              "evidence_snapshot_id",
              "verified_at"
            ]
          }
        },
        {
          "if": {
            "properties": {
              "knowledge_state": {
                "const": "UNKNOWN"
              }
            },
            "required": [
              "knowledge_state"
            ]
          },
          "then": {
            "properties": {
              "typed_value": {
                "type": "null"
              }
            },
            "required": [
              "typed_value"
            ]
          }
        }
      ],
      "description": "Immutable `last_verified_at` rule fact for one campaign_terms_snapshots.id rule-set snapshot. KNOWN typed_value is validated by HONOR_CAMPAIGN_RULE_REGISTRY.json key `last_verified_at`."
    }
  ],
  "description": "Exact per-key immutable campaign rule fact. Each oneOf branch binds rule_key to that key\u2019s registered typed_value schema; generic cross-key typed values cannot satisfy an incompatible rule key.",
  "x-honor-key-registry": "HONOR_CAMPAIGN_RULE_REGISTRY.json"
}
```

### `CampaignSummary`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "provider": {
      "type": "string"
    },
    "campaign_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "external_campaign_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "status": {
      "$ref": "#/components/schemas/CampaignStatus"
    },
    "title": {
      "type": "string"
    },
    "currency": {
      "type": "string",
      "pattern": "^[A-Z]{3}$"
    },
    "start_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "end_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "deadline_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "last_verified_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "provider",
    "campaign_url",
    "external_campaign_id",
    "status",
    "title",
    "currency",
    "start_at",
    "end_at",
    "deadline_at",
    "last_verified_at"
  ]
}
```

### `CampaignDetail`
```json
{
  "type": "object",
  "properties": {
    "campaign": {
      "$ref": "#/components/schemas/CampaignSummary"
    },
    "terms_snapshot_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "rules": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/CampaignRuleItem"
      },
      "minItems": 0,
      "maxItems": 100
    }
  },
  "additionalProperties": false,
  "required": [
    "campaign",
    "terms_snapshot_id",
    "rules"
  ]
}
```

### `CampaignOwnerUrlImport`
```json
{
  "type": "object",
  "properties": {
    "method": {
      "const": "OWNER_URL",
      "type": "string"
    },
    "provider": {
      "type": "string",
      "minLength": 1
    },
    "campaign_url": {
      "type": "string",
      "format": "uri"
    }
  },
  "additionalProperties": false,
  "required": [
    "method",
    "provider",
    "campaign_url"
  ]
}
```

### `CampaignManualImport`
```json
{
  "type": "object",
  "properties": {
    "method": {
      "const": "MANUAL",
      "type": "string"
    },
    "provider": {
      "type": "string",
      "minLength": 1
    },
    "title": {
      "type": "string",
      "minLength": 1
    },
    "campaign_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "external_campaign_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "terms_text": {
      "anyOf": [
        {
          "type": "string",
          "minLength": 1,
          "maxLength": 200000
        },
        {
          "type": "null"
        }
      ]
    },
    "terms_upload_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "method",
    "provider",
    "title",
    "campaign_url",
    "external_campaign_id",
    "terms_text",
    "terms_upload_id"
  ],
  "allOf": [
    {
      "anyOf": [
        {
          "properties": {
            "terms_text": {
              "type": "string",
              "minLength": 1
            }
          },
          "required": [
            "terms_text"
          ]
        },
        {
          "properties": {
            "terms_upload_id": {
              "type": "string",
              "format": "uuid"
            }
          },
          "required": [
            "terms_upload_id"
          ]
        }
      ]
    }
  ]
}
```

### `CampaignOfficialApiImport`
```json
{
  "type": "object",
  "properties": {
    "method": {
      "const": "OFFICIAL_API",
      "type": "string"
    },
    "provider": {
      "type": "string",
      "minLength": 1,
      "not": {
        "const": "UNKNOWN"
      }
    },
    "external_campaign_id": {
      "type": "string",
      "minLength": 1
    },
    "campaign_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "method",
    "provider",
    "external_campaign_id",
    "campaign_url"
  ]
}
```

### `CampaignImportRequest`
```json
{
  "oneOf": [
    {
      "$ref": "#/components/schemas/CampaignOwnerUrlImport"
    },
    {
      "$ref": "#/components/schemas/CampaignManualImport"
    },
    {
      "$ref": "#/components/schemas/CampaignOfficialApiImport"
    }
  ],
  "discriminator": {
    "propertyName": "method",
    "mapping": {
      "OWNER_URL": "#/components/schemas/CampaignOwnerUrlImport",
      "MANUAL": "#/components/schemas/CampaignManualImport",
      "OFFICIAL_API": "#/components/schemas/CampaignOfficialApiImport"
    }
  }
}
```

### `CampaignImportAccepted`
```json
{
  "type": "object",
  "properties": {
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "job_id": {
      "type": "string",
      "format": "uuid"
    },
    "status": {
      "type": "string",
      "const": "VERIFYING"
    },
    "correlation_id": {
      "type": "string",
      "format": "uuid"
    }
  },
  "additionalProperties": false,
  "required": [
    "campaign_id",
    "job_id",
    "status",
    "correlation_id"
  ]
}
```

### `UploadIntentRequest`
```json
{
  "type": "object",
  "properties": {
    "purpose": {
      "$ref": "#/components/schemas/UploadPurpose"
    },
    "filename": {
      "type": "string",
      "minLength": 1,
      "maxLength": 255
    },
    "content_type": {
      "type": "string",
      "minLength": 3,
      "maxLength": 255
    },
    "size_bytes": {
      "type": "integer",
      "minimum": 1,
      "maximum": 2147483648
    },
    "sha256": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$"
    }
  },
  "additionalProperties": false,
  "required": [
    "purpose",
    "filename",
    "content_type",
    "size_bytes",
    "sha256"
  ]
}
```

### `UploadIntentResponse`
```json
{
  "type": "object",
  "properties": {
    "upload_id": {
      "type": "string",
      "format": "uuid"
    },
    "state": {
      "type": "string",
      "const": "INTENT_CREATED"
    },
    "method": {
      "type": "string",
      "const": "PUT"
    },
    "upload_url": {
      "type": "string",
      "format": "uri"
    },
    "required_headers": {
      "type": "object",
      "additionalProperties": {
        "type": "string"
      }
    },
    "expires_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "upload_id",
    "state",
    "method",
    "upload_url",
    "required_headers",
    "expires_at"
  ]
}
```

### `UploadCompleteRequest`
```json
{
  "type": "object",
  "properties": {
    "size_bytes": {
      "type": "integer",
      "minimum": 1,
      "maximum": 2147483648
    },
    "sha256": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$"
    }
  },
  "additionalProperties": false,
  "required": [
    "size_bytes",
    "sha256"
  ]
}
```

### `UploadRecord`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "purpose": {
      "$ref": "#/components/schemas/UploadPurpose"
    },
    "state": {
      "$ref": "#/components/schemas/UploadState"
    },
    "filename": {
      "type": "string"
    },
    "content_type": {
      "type": "string"
    },
    "size_bytes": {
      "type": "integer"
    },
    "sha256": {
      "type": "string",
      "pattern": "^[a-f0-9]{64}$"
    },
    "expires_at": {
      "type": "string",
      "format": "date-time"
    },
    "verified_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "purpose",
    "state",
    "filename",
    "content_type",
    "size_bytes",
    "sha256",
    "expires_at",
    "verified_at"
  ]
}
```

### `RightsEvidenceInput`
```json
{
  "type": "object",
  "properties": {
    "eligibility": {
      "$ref": "#/components/schemas/SourceEligibility"
    },
    "evidence_type": {
      "type": "string",
      "minLength": 1
    },
    "evidence_upload_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "evidence_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "authorized_uses": {
      "$ref": "jsonschema/source_rights.authorized_uses.v1.json"
    },
    "platform_limits": {
      "$ref": "jsonschema/source_rights.platform_limits.v1.json"
    },
    "expires_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "eligibility",
    "evidence_type",
    "evidence_upload_id",
    "evidence_url",
    "authorized_uses",
    "platform_limits",
    "expires_at"
  ],
  "allOf": [
    {
      "anyOf": [
        {
          "properties": {
            "evidence_upload_id": {
              "type": "string",
              "format": "uuid"
            }
          },
          "required": [
            "evidence_upload_id"
          ]
        },
        {
          "properties": {
            "evidence_url": {
              "type": "string",
              "format": "uri"
            }
          },
          "required": [
            "evidence_url"
          ]
        }
      ]
    }
  ]
}
```

### `SourceOwnerUrlImport`
```json
{
  "type": "object",
  "properties": {
    "method": {
      "const": "OWNER_URL",
      "type": "string"
    },
    "origin_type": {
      "$ref": "#/components/schemas/SourceOrigin"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "provider": {
      "type": "string",
      "minLength": 1
    },
    "source_url": {
      "type": "string",
      "format": "uri"
    },
    "rights": {
      "$ref": "#/components/schemas/RightsEvidenceInput"
    }
  },
  "additionalProperties": false,
  "required": [
    "method",
    "origin_type",
    "campaign_id",
    "provider",
    "source_url",
    "rights"
  ]
}
```

### `SourceManualUploadImport`
```json
{
  "type": "object",
  "properties": {
    "method": {
      "const": "MANUAL_UPLOAD",
      "type": "string"
    },
    "origin_type": {
      "$ref": "#/components/schemas/SourceOrigin"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "provider": {
      "type": "string",
      "minLength": 1
    },
    "upload_id": {
      "type": "string",
      "format": "uuid"
    },
    "title": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "rights": {
      "$ref": "#/components/schemas/RightsEvidenceInput"
    }
  },
  "additionalProperties": false,
  "required": [
    "method",
    "origin_type",
    "campaign_id",
    "provider",
    "upload_id",
    "title",
    "rights"
  ]
}
```

### `SourceAuthorizedApiImport`
```json
{
  "type": "object",
  "properties": {
    "method": {
      "const": "AUTHORIZED_API",
      "type": "string"
    },
    "origin_type": {
      "$ref": "#/components/schemas/SourceOrigin"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "provider": {
      "type": "string",
      "minLength": 1
    },
    "external_source_id": {
      "type": "string",
      "minLength": 1
    },
    "source_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "rights": {
      "$ref": "#/components/schemas/RightsEvidenceInput"
    }
  },
  "additionalProperties": false,
  "required": [
    "method",
    "origin_type",
    "campaign_id",
    "provider",
    "external_source_id",
    "source_url",
    "rights"
  ]
}
```

### `SourceImportRequest`
```json
{
  "oneOf": [
    {
      "$ref": "#/components/schemas/SourceOwnerUrlImport"
    },
    {
      "$ref": "#/components/schemas/SourceManualUploadImport"
    },
    {
      "$ref": "#/components/schemas/SourceAuthorizedApiImport"
    }
  ],
  "discriminator": {
    "propertyName": "method",
    "mapping": {
      "OWNER_URL": "#/components/schemas/SourceOwnerUrlImport",
      "MANUAL_UPLOAD": "#/components/schemas/SourceManualUploadImport",
      "AUTHORIZED_API": "#/components/schemas/SourceAuthorizedApiImport"
    }
  }
}
```

### `SourceImportAccepted`
```json
{
  "type": "object",
  "properties": {
    "source_id": {
      "type": "string",
      "format": "uuid"
    },
    "job_id": {
      "type": "string",
      "format": "uuid"
    },
    "ingest_status": {
      "$ref": "#/components/schemas/SourceIngestStatus"
    },
    "correlation_id": {
      "type": "string",
      "format": "uuid"
    }
  },
  "additionalProperties": false,
  "required": [
    "source_id",
    "job_id",
    "ingest_status",
    "correlation_id"
  ]
}
```

### `SourceRecord`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "origin_type": {
      "$ref": "#/components/schemas/SourceOrigin"
    },
    "source_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "provider": {
      "type": "string"
    },
    "external_source_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "title": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "sha256": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^[a-f0-9]{64}$"
        },
        {
          "type": "null"
        }
      ]
    },
    "duration_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "ingest_status": {
      "$ref": "#/components/schemas/SourceIngestStatus"
    },
    "eligibility": {
      "$ref": "#/components/schemas/SourceEligibility"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "origin_type",
    "source_url",
    "provider",
    "external_source_id",
    "title",
    "sha256",
    "duration_ms",
    "ingest_status",
    "eligibility",
    "created_at",
    "updated_at"
  ]
}
```

### `PostingRecommendation`
```json
{
  "$ref": "jsonschema/clip.posting_recommendation.v1.json"
}
```

### `ClipSummary`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "generation_run_id": {
      "type": "string",
      "format": "uuid"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "source_id": {
      "type": "string",
      "format": "uuid"
    },
    "social_account_id": {
      "type": "string",
      "format": "uuid"
    },
    "state": {
      "$ref": "#/components/schemas/ClipState"
    },
    "duration_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "generation_run_id",
    "campaign_id",
    "source_id",
    "social_account_id",
    "state",
    "duration_ms",
    "created_at"
  ]
}
```

### `ClipDetail`
```json
{
  "type": "object",
  "properties": {
    "clip": {
      "$ref": "#/components/schemas/ClipSummary"
    },
    "width": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 1
        },
        {
          "type": "null"
        }
      ]
    },
    "height": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 1
        },
        {
          "type": "null"
        }
      ]
    },
    "codec": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "file_size_bytes": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "sha256": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^[a-f0-9]{64}$"
        },
        {
          "type": "null"
        }
      ]
    },
    "download_url": {
      "anyOf": [
        {
          "type": "string",
          "format": "uri"
        },
        {
          "type": "null"
        }
      ]
    },
    "download_url_expires_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "posting_recommendation": {
      "$ref": "#/components/schemas/PostingRecommendation"
    },
    "rule_snapshot_id": {
      "type": "string",
      "format": "uuid"
    },
    "rights_id": {
      "type": "string",
      "format": "uuid"
    },
    "edit_plan_id": {
      "type": "string",
      "format": "uuid"
    },
    "audio_plan_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "render_manifest_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "clip",
    "width",
    "height",
    "codec",
    "file_size_bytes",
    "sha256",
    "download_url",
    "download_url_expires_at",
    "posting_recommendation",
    "rule_snapshot_id",
    "rights_id",
    "edit_plan_id",
    "audio_plan_id",
    "render_manifest_id"
  ]
}
```

### `ScheduleItem`
```json
{
  "type": "object",
  "properties": {
    "clip_id": {
      "type": "string",
      "format": "uuid"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "social_account_id": {
      "type": "string",
      "format": "uuid"
    },
    "platform": {
      "$ref": "#/components/schemas/Platform"
    },
    "recommended_publish_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "posting_recommendation": {
      "$ref": "#/components/schemas/PostingRecommendation"
    }
  },
  "additionalProperties": false,
  "required": [
    "clip_id",
    "campaign_id",
    "social_account_id",
    "platform",
    "recommended_publish_at",
    "posting_recommendation"
  ]
}
```

### `TomorrowSchedule`
```json
{
  "type": "object",
  "properties": {
    "target_date": {
      "type": "string",
      "format": "date"
    },
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/ScheduleItem"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "generated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "target_date",
    "items",
    "generated_at"
  ],
  "description": "Owner posting schedule as of generated_at. Items are current-authorized recommendations only; latest-rights revalidation occurs at response time and historical clips remain unchanged if later rights narrow/revoke."
}
```

### `PostCreateRequest`
```json
{
  "type": "object",
  "properties": {
    "clip_id": {
      "type": "string",
      "format": "uuid"
    },
    "social_account_id": {
      "type": "string",
      "format": "uuid"
    },
    "platform": {
      "$ref": "#/components/schemas/Platform"
    },
    "published_at": {
      "type": "string",
      "format": "date-time"
    },
    "post_url": {
      "type": "string",
      "format": "uri"
    },
    "platform_post_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "native_audio_used": {
      "anyOf": [
        {
          "$ref": "#/components/schemas/PostNativeAudioUsedV1"
        },
        {
          "type": "null"
        }
      ]
    },
    "owner_notes": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 4000
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "clip_id",
    "social_account_id",
    "platform",
    "published_at",
    "post_url",
    "platform_post_id",
    "native_audio_used",
    "owner_notes"
  ]
}
```

### `PostRecord`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "clip_id": {
      "type": "string",
      "format": "uuid"
    },
    "social_account_id": {
      "type": "string",
      "format": "uuid"
    },
    "platform": {
      "$ref": "#/components/schemas/Platform"
    },
    "published_at": {
      "type": "string",
      "format": "date-time"
    },
    "post_url": {
      "type": "string",
      "format": "uri"
    },
    "platform_post_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "native_audio_used": {
      "anyOf": [
        {
          "$ref": "jsonschema/post.native_audio_used.v1.json"
        },
        {
          "type": "null"
        }
      ]
    },
    "owner_notes": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "status": {
      "$ref": "#/components/schemas/PostStatus"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "clip_id",
    "social_account_id",
    "platform",
    "published_at",
    "post_url",
    "platform_post_id",
    "native_audio_used",
    "owner_notes",
    "status",
    "created_at",
    "updated_at"
  ]
}
```

### `SubmissionRequest`
```json
{
  "type": "object",
  "properties": {
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "status": {
      "$ref": "#/components/schemas/SubmissionStatus",
      "description": "On create: PENDING|SUBMITTED|NOT_REQUIRED|UNKNOWN. On update: requested state must follow canonical transition graph; ACCEPTED/REJECTED are valid only from SUBMITTED or UNKNOWN.",
      "x-honor-creation-allowed-values": [
        "PENDING",
        "SUBMITTED",
        "NOT_REQUIRED",
        "UNKNOWN"
      ],
      "x-honor-transition-allowed-values-by-current-state": {
        "PENDING": [
          "SUBMITTED",
          "NOT_REQUIRED",
          "UNKNOWN"
        ],
        "SUBMITTED": [
          "ACCEPTED",
          "REJECTED",
          "UNKNOWN"
        ],
        "UNKNOWN": [
          "PENDING",
          "SUBMITTED",
          "NOT_REQUIRED",
          "ACCEPTED",
          "REJECTED"
        ],
        "ACCEPTED": [],
        "REJECTED": [],
        "NOT_REQUIRED": []
      }
    },
    "submitted_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "submission_reference": {
      "anyOf": [
        {
          "type": "string",
          "maxLength": 2000
        },
        {
          "type": "null"
        }
      ]
    },
    "evidence_upload_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "campaign_id",
    "post_id",
    "status",
    "submitted_at",
    "submission_reference",
    "evidence_upload_id"
  ]
}
```

### `SubmissionRecord`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "submitted_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "submission_reference": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "status": {
      "$ref": "#/components/schemas/SubmissionStatus"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "campaign_id",
    "post_id",
    "submitted_at",
    "submission_reference",
    "status",
    "created_at",
    "updated_at"
  ]
}
```

### `AnalyticsObservationInput`
```json
{
  "type": "object",
  "properties": {
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "checkin_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "observed_at": {
      "type": "string",
      "format": "date-time"
    },
    "views": {
      "type": "integer",
      "minimum": 0
    },
    "qualified_views": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "likes": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "comments": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "shares": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "saves": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ]
    },
    "watch_time_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0
        },
        {
          "type": "null"
        }
      ],
      "description": "TOTAL cumulative watch time across observed views, in milliseconds; never average watch duration."
    },
    "avg_watch_pct": {
      "anyOf": [
        {
          "type": "number",
          "minimum": 0,
          "maximum": 100
        },
        {
          "type": "null"
        }
      ]
    },
    "evidence_method": {
      "$ref": "#/components/schemas/AnalyticsEvidenceMethod"
    },
    "evidence_upload_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "average_watch_duration_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "description": "Average watch duration per view when explicitly supplied by authoritative evidence; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "completed_views": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "description": "Authoritatively supplied count of completed views; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "completion_rate_ppm": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000000,
          "description": "Completion ratio in parts-per-million; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "follower_delta": {
      "anyOf": [
        {
          "type": "integer",
          "description": "Net follower change attributable to the platform observation window when supplied; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "post_id",
    "checkin_id",
    "observed_at",
    "views",
    "qualified_views",
    "likes",
    "comments",
    "shares",
    "saves",
    "watch_time_ms",
    "average_watch_duration_ms",
    "completed_views",
    "completion_rate_ppm",
    "follower_delta",
    "avg_watch_pct",
    "evidence_method",
    "evidence_upload_id"
  ]
}
```

### `AnalyticsObservation`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "checkin_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "observed_at": {
      "type": "string",
      "format": "date-time"
    },
    "views": {
      "type": "integer"
    },
    "qualified_views": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ]
    },
    "likes": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ]
    },
    "comments": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ]
    },
    "shares": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ]
    },
    "saves": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ]
    },
    "watch_time_ms": {
      "anyOf": [
        {
          "type": "integer"
        },
        {
          "type": "null"
        }
      ],
      "description": "Total cumulative watch time in milliseconds across observed views; null when unavailable. Never average watch duration."
    },
    "avg_watch_pct": {
      "anyOf": [
        {
          "type": "number"
        },
        {
          "type": "null"
        }
      ]
    },
    "evidence_method": {
      "$ref": "#/components/schemas/AnalyticsEvidenceMethod"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "average_watch_duration_ms": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "description": "Average watch duration per view when explicitly supplied by authoritative evidence; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "completed_views": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "description": "Authoritatively supplied count of completed views; null when unavailable."
        },
        {
          "type": "null"
        }
      ]
    },
    "completion_rate_ppm": {
      "anyOf": [
        {
          "type": "integer",
          "minimum": 0,
          "maximum": 1000000,
          "description": "Completion ratio in parts-per-million; null when unavailable."
        },
        {
          "type": "null"
        }
      ],
      "description": "Provider/evidence supplied completion rate in parts per million (0..1,000,000); null when unavailable. Do not manufacture zero."
    },
    "follower_delta": {
      "anyOf": [
        {
          "type": "integer",
          "description": "Net follower change attributable to the platform observation window when supplied; null when unavailable."
        },
        {
          "type": "null"
        }
      ],
      "description": "Net follower change attributable to the observation window only when provider/evidence supplies it; null when unavailable."
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "post_id",
    "checkin_id",
    "observed_at",
    "views",
    "qualified_views",
    "likes",
    "comments",
    "shares",
    "saves",
    "watch_time_ms",
    "average_watch_duration_ms",
    "completed_views",
    "completion_rate_ppm",
    "follower_delta",
    "avg_watch_pct",
    "evidence_method",
    "created_at"
  ]
}
```

### `AnalyticsCheckin`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "type": "string",
      "format": "uuid"
    },
    "checkin_type": {
      "$ref": "#/components/schemas/CheckinType"
    },
    "due_at": {
      "type": "string",
      "format": "date-time"
    },
    "completed_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "status": {
      "$ref": "#/components/schemas/CheckinStatus"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "post_id",
    "checkin_type",
    "due_at",
    "completed_at",
    "status",
    "created_at",
    "updated_at"
  ]
}
```

### `AnalyticsCheckinResult`
```json
{
  "type": "object",
  "properties": {
    "observation": {
      "$ref": "#/components/schemas/AnalyticsObservation"
    },
    "checkin": {
      "anyOf": [
        {
          "$ref": "#/components/schemas/AnalyticsCheckin"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "observation",
    "checkin"
  ]
}
```

### `EarningLocator`
```json
{
  "type": "object",
  "properties": {
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "post_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "external_earning_id": {
      "anyOf": [
        {
          "type": "string",
          "minLength": 1
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "campaign_id",
    "post_id",
    "external_earning_id"
  ],
  "allOf": [
    {
      "anyOf": [
        {
          "properties": {
            "post_id": {
              "type": "string",
              "format": "uuid"
            }
          },
          "required": [
            "post_id"
          ]
        },
        {
          "properties": {
            "external_earning_id": {
              "type": "string",
              "minLength": 1
            }
          },
          "required": [
            "external_earning_id"
          ]
        }
      ]
    }
  ]
}
```

### `PayoutCreateEvent`
```json
{
  "type": "object",
  "properties": {
    "event_kind": {
      "type": "string",
      "const": "CREATE"
    },
    "earning_locator": {
      "$ref": "#/components/schemas/EarningLocator"
    },
    "amount_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "to_state": {
      "type": "string",
      "const": "ACCRUED_UNVERIFIED"
    },
    "occurred_at": {
      "type": "string",
      "format": "date-time"
    },
    "source": {
      "type": "string",
      "enum": [
        "OWNER_MANUAL",
        "OFFICIAL_API",
        "COMPLIANT_IMPORT"
      ]
    },
    "evidence_snapshot_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "event_kind",
    "earning_locator",
    "amount_usd",
    "to_state",
    "occurred_at",
    "source",
    "evidence_snapshot_id"
  ]
}
```

### `PayoutTransitionEvent`
```json
{
  "type": "object",
  "properties": {
    "event_kind": {
      "type": "string",
      "const": "TRANSITION"
    },
    "earning_id": {
      "type": "string",
      "format": "uuid"
    },
    "to_state": {
      "type": "string",
      "enum": [
        "APPROVED",
        "WITHDRAWABLE",
        "WITHDRAWN",
        "VOIDED"
      ]
    },
    "occurred_at": {
      "type": "string",
      "format": "date-time"
    },
    "source": {
      "type": "string",
      "enum": [
        "OWNER_MANUAL",
        "OFFICIAL_API",
        "COMPLIANT_IMPORT"
      ]
    },
    "evidence_snapshot_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "event_kind",
    "earning_id",
    "to_state",
    "occurred_at",
    "source",
    "evidence_snapshot_id"
  ]
}
```

### `PayoutEventRequest`
```json
{
  "oneOf": [
    {
      "$ref": "#/components/schemas/PayoutCreateEvent"
    },
    {
      "$ref": "#/components/schemas/PayoutTransitionEvent"
    }
  ],
  "discriminator": {
    "propertyName": "event_kind",
    "mapping": {
      "CREATE": "#/components/schemas/PayoutCreateEvent",
      "TRANSITION": "#/components/schemas/PayoutTransitionEvent"
    }
  }
}
```

### `EarningRecord`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "campaign_id": {
      "type": "string",
      "format": "uuid"
    },
    "rule_snapshot_id": {
      "type": "string",
      "format": "uuid",
      "description": "Exact sealed campaign rule snapshot governing the earning provenance."
    },
    "post_id": {
      "anyOf": [
        {
          "type": "string",
          "format": "uuid"
        },
        {
          "type": "null"
        }
      ]
    },
    "external_earning_id": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ]
    },
    "amount_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "state": {
      "$ref": "#/components/schemas/EarningState"
    },
    "recognized_at": {
      "type": "string",
      "format": "date-time"
    },
    "last_state_at": {
      "type": "string",
      "format": "date-time"
    },
    "source": {
      "type": "string",
      "enum": [
        "OWNER_MANUAL",
        "OFFICIAL_API",
        "COMPLIANT_IMPORT"
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "campaign_id",
    "rule_snapshot_id",
    "post_id",
    "external_earning_id",
    "amount_usd",
    "state",
    "recognized_at",
    "last_state_at",
    "source"
  ]
}
```

### `FinanceSummary`
```json
{
  "type": "object",
  "properties": {
    "as_of": {
      "type": "string",
      "format": "date-time"
    },
    "currency": {
      "type": "string",
      "const": "USD"
    },
    "accrued_unverified_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "approved_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "withdrawable_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "withdrawn_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "gross_campaign_revenue_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "infrastructure_api_spend_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "polli_voice_reasoning_spend_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "lifetime_revenue_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "lifetime_spend_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "net_profit_usd": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^-?(0|[1-9][0-9]*)\\.[0-9]{6}$"
        },
        {
          "type": "null"
        }
      ],
      "description": "Null when material cost data is incomplete; never substituted with zero."
    },
    "monthly_target_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "monthly_target_progress_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "net_profit_truth_state": {
      "type": "string",
      "enum": [
        "FACT",
        "INCOMPLETE_UNKNOWN"
      ],
      "description": "FACT only when net_profit_usd is present and material cost data is sufficiently complete; INCOMPLETE_UNKNOWN requires net_profit_usd=null."
    },
    "self_funded_state": {
      "type": "string",
      "enum": [
        "FACTORY_SELF_FUNDED",
        "NOT_SELF_FUNDED",
        "UNKNOWN_NOT_VERIFIED"
      ],
      "description": "Canonical tri-state. UNKNOWN_NOT_VERIFIED is required when material revenue/cost evidence is incomplete; it must not be collapsed to false."
    }
  },
  "additionalProperties": false,
  "required": [
    "as_of",
    "currency",
    "accrued_unverified_usd",
    "approved_usd",
    "withdrawable_usd",
    "withdrawn_usd",
    "gross_campaign_revenue_usd",
    "infrastructure_api_spend_usd",
    "polli_voice_reasoning_spend_usd",
    "lifetime_revenue_usd",
    "lifetime_spend_usd",
    "net_profit_usd",
    "monthly_target_usd",
    "monthly_target_progress_usd",
    "net_profit_truth_state",
    "self_funded_state"
  ]
}
```

### `CostGroup`
```json
{
  "type": "object",
  "properties": {
    "group": {
      "type": "string"
    },
    "estimated_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "actual_usd": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
          "description": "Exact USD decimal with six fractional digits; never a JSON number."
        },
        {
          "type": "null"
        }
      ]
    },
    "confidence": {
      "$ref": "#/components/schemas/Confidence"
    }
  },
  "additionalProperties": false,
  "required": [
    "group",
    "estimated_usd",
    "actual_usd",
    "confidence"
  ]
}
```

### `CostSummary`
```json
{
  "type": "object",
  "properties": {
    "as_of": {
      "type": "string",
      "format": "date-time"
    },
    "month": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}$"
    },
    "cash_spend_counted_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "unpaid_committed_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "admitted_queued_unfunded_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "prepaid_funding_purchased_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "prepaid_credit_remaining_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "governor_exposure_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "projected_month_end_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact non-negative USD decimal string with six fractional digits."
    },
    "remaining_hard_cap_usd": {
      "type": "string",
      "pattern": "^-?(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
      "description": "Exact USD decimal string with six fractional digits; never a JSON number."
    },
    "hard_cap_usd": {
      "type": "string",
      "const": "56.030000"
    },
    "optional_pause_usd": {
      "type": "string",
      "const": "43.000000"
    },
    "reserve_mode_usd": {
      "type": "string",
      "const": "51.030000"
    },
    "governor_state": {
      "type": "string",
      "enum": [
        "NORMAL",
        "OPTIONAL_PAUSED",
        "RESERVE",
        "HARD_STOP"
      ]
    },
    "groups": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/CostGroup"
      },
      "minItems": 0,
      "maxItems": 100
    }
  },
  "additionalProperties": false,
  "required": [
    "as_of",
    "month",
    "cash_spend_counted_usd",
    "unpaid_committed_usd",
    "admitted_queued_unfunded_usd",
    "prepaid_funding_purchased_usd",
    "prepaid_credit_remaining_usd",
    "governor_exposure_usd",
    "projected_month_end_usd",
    "remaining_hard_cap_usd",
    "hard_cap_usd",
    "optional_pause_usd",
    "reserve_mode_usd",
    "governor_state",
    "groups"
  ],
  "description": "Deterministic Month-1 cost governor snapshot. governor_exposure_usd = cash_spend_counted_usd + unpaid_committed_usd + admitted_queued_unfunded_usd using exact decimal arithmetic. NORMAL is exposure <43.000000; OPTIONAL_PAUSED is >=43.000000 and <51.030000; RESERVE is >=51.030000 and <56.030000; HARD_STOP is >=56.030000. No new optional paid work may be admitted when exposure is >=43.000000. Every paid action is evaluated against post-admission exposure before dispatch. Prepaid funding is counted in full at purchase in cash_spend_counted_usd; later usage of that already-counted credit is not double-counted. projected_month_end_usd is informational and can never loosen admission. HONOR_COST_GOVERNOR.json is authoritative."
}
```

### `PolliSessionCreateRequest`
```json
{
  "type": "object",
  "properties": {
    "mode": {
      "$ref": "#/components/schemas/PolliMode"
    },
    "retention_mode": {
      "type": "string",
      "const": "TRANSCRIPT_SUMMARY"
    }
  },
  "additionalProperties": false,
  "required": [
    "mode",
    "retention_mode"
  ]
}
```

### `PolliSession`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "mode": {
      "$ref": "#/components/schemas/PolliMode"
    },
    "status": {
      "$ref": "#/components/schemas/PolliSessionStatus"
    },
    "started_at": {
      "type": "string",
      "format": "date-time"
    },
    "ended_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "backend_model_route": {
      "type": "string"
    },
    "estimated_cost_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    },
    "actual_cost_usd": {
      "anyOf": [
        {
          "type": "string",
          "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
          "description": "Exact USD decimal with six fractional digits; never a JSON number."
        },
        {
          "type": "null"
        }
      ]
    },
    "retention_mode": {
      "type": "string",
      "const": "TRANSCRIPT_SUMMARY"
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "mode",
    "status",
    "started_at",
    "ended_at",
    "backend_model_route",
    "estimated_cost_usd",
    "actual_cost_usd",
    "retention_mode"
  ]
}
```

### `PolliLiveSessionRequest`
```json
{
  "type": "object",
  "properties": {
    "polli_session_id": {
      "type": "string",
      "format": "uuid"
    },
    "sdp_offer": {
      "type": "string",
      "minLength": 1,
      "maxLength": 200000
    }
  },
  "additionalProperties": false,
  "required": [
    "polli_session_id",
    "sdp_offer"
  ]
}
```

### `PolliLiveSessionResponse`
```json
{
  "type": "object",
  "properties": {
    "polli_session_id": {
      "type": "string",
      "format": "uuid"
    },
    "live_session_ref": {
      "type": "string",
      "minLength": 1
    },
    "sdp_answer": {
      "type": "string",
      "minLength": 1
    },
    "expires_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": false,
  "required": [
    "polli_session_id",
    "live_session_ref",
    "sdp_answer",
    "expires_at"
  ]
}
```

### `PolliQueryRequest`
```json
{
  "type": "object",
  "properties": {
    "session_id": {
      "type": "string",
      "format": "uuid"
    },
    "question": {
      "type": "string",
      "minLength": 1,
      "maxLength": 8000
    }
  },
  "additionalProperties": false,
  "required": [
    "session_id",
    "question"
  ]
}
```

### `PolliClaim`
```json
{
  "type": "object",
  "properties": {
    "label": {
      "$ref": "#/components/schemas/TruthLabel"
    },
    "text": {
      "type": "string",
      "minLength": 1
    },
    "value": {
      "anyOf": [
        {},
        {
          "type": "null"
        }
      ]
    },
    "as_of": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "sources": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "minItems": 0,
      "maxItems": 20
    },
    "warnings": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "minItems": 0,
      "maxItems": 20
    }
  },
  "additionalProperties": false,
  "required": [
    "label",
    "text",
    "value",
    "as_of",
    "sources",
    "warnings"
  ]
}
```

### `PolliToolCallSummary`
```json
{
  "type": "object",
  "properties": {
    "tool_name": {
      "type": "string"
    },
    "ok": {
      "type": "boolean"
    },
    "label": {
      "$ref": "#/components/schemas/TruthLabel"
    },
    "cost_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    }
  },
  "additionalProperties": false,
  "required": [
    "tool_name",
    "ok",
    "label",
    "cost_usd"
  ]
}
```

### `PolliQueryResponse`
```json
{
  "type": "object",
  "properties": {
    "session_id": {
      "type": "string",
      "format": "uuid"
    },
    "answer": {
      "type": "string"
    },
    "label": {
      "$ref": "#/components/schemas/TruthLabel"
    },
    "claims": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/PolliClaim"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "tool_calls": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/PolliToolCallSummary"
      },
      "minItems": 0,
      "maxItems": 50
    },
    "as_of": {
      "type": "string",
      "format": "date-time"
    },
    "cost_usd": {
      "type": "string",
      "pattern": "^(0|[1-9][0-9]*)\\.[0-9]{6}$",
      "description": "Exact USD decimal with six fractional digits; never a JSON number."
    }
  },
  "additionalProperties": false,
  "required": [
    "session_id",
    "answer",
    "label",
    "claims",
    "tool_calls",
    "as_of",
    "cost_usd"
  ]
}
```

### `PolliSessionEndRequest`
```json
{
  "type": "object",
  "properties": {},
  "additionalProperties": false
}
```

### `OwnerAction`
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "format": "uuid"
    },
    "action_type": {
      "type": "string",
      "enum": [
        "CAMPAIGN_RULE",
        "SOURCE_RIGHTS",
        "PROVIDER_SETUP",
        "GENERIC_CONFIRMATION"
      ]
    },
    "title": {
      "type": "string"
    },
    "reason": {
      "type": "string"
    },
    "entity_type": {
      "type": "string"
    },
    "entity_id": {
      "type": "string",
      "format": "uuid"
    },
    "status": {
      "$ref": "#/components/schemas/OwnerActionStatus"
    },
    "requested_at": {
      "type": "string",
      "format": "date-time"
    },
    "resolved_at": {
      "anyOf": [
        {
          "type": "string",
          "format": "date-time"
        },
        {
          "type": "null"
        }
      ]
    },
    "resolution": {
      "anyOf": [
        {
          "$ref": "#/components/schemas/OwnerActionResolutionV1"
        },
        {
          "type": "null"
        }
      ]
    }
  },
  "additionalProperties": false,
  "required": [
    "id",
    "action_type",
    "title",
    "reason",
    "entity_type",
    "entity_id",
    "status",
    "requested_at",
    "resolved_at",
    "resolution"
  ]
}
```

### `OwnerActionResolveRequest`
```json
{
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "const": "RESOLVED"
        },
        "resolution": {
          "oneOf": [
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "CAMPAIGN_RULE"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "CONFIRM_VALUE",
                    "MARK_UNKNOWN",
                    "MARK_NOT_APPLICABLE"
                  ]
                },
                "rule_key": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 200
                },
                "typed_value": {
                  "anyOf": [
                    {
                      "oneOf": [
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "STRING"
                            },
                            "value": {
                              "type": "string",
                              "maxLength": 200000
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "STRING_ARRAY"
                            },
                            "value": {
                              "type": "array",
                              "items": {
                                "type": "string",
                                "maxLength": 500
                              },
                              "minItems": 0,
                              "maxItems": 200,
                              "uniqueItems": true
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "INTEGER"
                            },
                            "value": {
                              "type": "integer"
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "BOOLEAN"
                            },
                            "value": {
                              "type": "boolean"
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "MONEY_USD"
                            },
                            "value": {
                              "type": "string",
                              "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
                              "description": "Exact non-negative USD decimal string with six fractional digits."
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "TIMESTAMP"
                            },
                            "value": {
                              "type": "string",
                              "format": "date-time"
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "DURATION_SECONDS"
                            },
                            "value": {
                              "type": "number",
                              "minimum": 0,
                              "maximum": 86400
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "PLATFORMS"
                            },
                            "value": {
                              "type": "array",
                              "items": {
                                "type": "string",
                                "enum": [
                                  "TIKTOK",
                                  "INSTAGRAM_REELS",
                                  "YOUTUBE_SHORTS"
                                ]
                              },
                              "minItems": 0,
                              "maxItems": 3,
                              "uniqueItems": true
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "REGIONS"
                            },
                            "value": {
                              "type": "array",
                              "items": {
                                "type": "string",
                                "pattern": "^[A-Z]{2}(-[A-Z0-9]{1,3})?$"
                              },
                              "minItems": 0,
                              "maxItems": 250,
                              "uniqueItems": true
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        },
                        {
                          "type": "object",
                          "properties": {
                            "value_type": {
                              "const": "RATE"
                            },
                            "value": {
                              "type": "object",
                              "properties": {
                                "amount": {
                                  "type": "string",
                                  "pattern": "^(0|[1-9][0-9]{0,11})\\.[0-9]{6}$",
                                  "description": "Exact non-negative USD decimal string with six fractional digits."
                                },
                                "basis": {
                                  "type": "string",
                                  "enum": [
                                    "FLAT",
                                    "PER_1000_VIEWS",
                                    "PER_QUALIFIED_ACTION",
                                    "OTHER"
                                  ]
                                },
                                "unit_description": {
                                  "anyOf": [
                                    {
                                      "type": "string",
                                      "maxLength": 500
                                    },
                                    {
                                      "type": "null"
                                    }
                                  ]
                                }
                              },
                              "additionalProperties": false,
                              "required": [
                                "amount",
                                "basis",
                                "unit_description"
                              ]
                            }
                          },
                          "additionalProperties": false,
                          "required": [
                            "value_type",
                            "value"
                          ]
                        }
                      ]
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "evidence_upload_id": {
                  "anyOf": [
                    {
                      "type": "string",
                      "format": "uuid"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "rule_key",
                "typed_value",
                "evidence_upload_id",
                "note"
              ]
            },
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "SOURCE_RIGHTS"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "AUTHORIZED",
                    "NOT_AUTHORIZED",
                    "UNKNOWN"
                  ]
                },
                "source_id": {
                  "type": "string",
                  "format": "uuid"
                },
                "evidence_upload_id": {
                  "anyOf": [
                    {
                      "type": "string",
                      "format": "uuid"
                    },
                    {
                      "type": "null"
                    }
                  ]
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "source_id",
                "evidence_upload_id",
                "note"
              ]
            },
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "PROVIDER_SETUP"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "COMPLETED",
                    "DEFERRED",
                    "BLOCKED"
                  ]
                },
                "provider": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 100
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "provider",
                "note"
              ]
            },
            {
              "type": "object",
              "properties": {
                "resolution_type": {
                  "const": "GENERIC_CONFIRMATION"
                },
                "decision": {
                  "type": "string",
                  "enum": [
                    "CONFIRMED",
                    "DECLINED"
                  ]
                },
                "note": {
                  "anyOf": [
                    {
                      "type": "string",
                      "maxLength": 2000
                    },
                    {
                      "type": "null"
                    }
                  ]
                }
              },
              "additionalProperties": false,
              "required": [
                "resolution_type",
                "decision",
                "note"
              ]
            }
          ]
        }
      },
      "additionalProperties": false,
      "required": [
        "status",
        "resolution"
      ]
    },
    {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "const": "CANCELLED"
        },
        "resolution": {
          "type": "object",
          "properties": {
            "resolution_type": {
              "const": "CANCELLED"
            },
            "reason": {
              "type": "string",
              "minLength": 1,
              "maxLength": 2000
            }
          },
          "additionalProperties": false,
          "required": [
            "resolution_type",
            "reason"
          ]
        }
      },
      "additionalProperties": false,
      "required": [
        "status",
        "resolution"
      ]
    }
  ]
}
```

### `CampaignList`
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/CampaignSummary"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```

### `ClipList`
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/ClipSummary"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```

### `AnalyticsDueList`
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/AnalyticsCheckin"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```

### `OwnerActionList`
```json
{
  "type": "object",
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "$ref": "#/components/schemas/OwnerAction"
      },
      "minItems": 0,
      "maxItems": 100
    },
    "page": {
      "$ref": "#/components/schemas/PageMeta"
    }
  },
  "additionalProperties": false,
  "required": [
    "items",
    "page"
  ]
}
```

### `Error_readyz_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_readyz_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_readyz_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createGenerationRun_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createGenerationRun_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createGenerationRun_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createGenerationRun_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createGenerationRun_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createGenerationRun_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getGenerationRun_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getGenerationRun_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getGenerationRun_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getGenerationRun_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getGenerationRun_404`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listCampaigns_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listCampaigns_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listCampaigns_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listCampaigns_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importCampaign_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importCampaign_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importCampaign_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importCampaign_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importCampaign_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importCampaign_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCampaign_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCampaign_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCampaign_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCampaign_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCampaign_404`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createUploadIntent_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createUploadIntent_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createUploadIntent_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createUploadIntent_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createUploadIntent_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createUploadIntent_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_completeUpload_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_completeUpload_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_completeUpload_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "UPLOAD_MISMATCH",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_completeUpload_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_completeUpload_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_completeUpload_404`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "UPLOAD_NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_completeUpload_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "UPLOAD_EXPIRED",
            "UPLOAD_MISMATCH"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importSource_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importSource_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN",
            "RIGHTS_UNVERIFIED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importSource_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "RIGHTS_UNVERIFIED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importSource_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importSource_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_importSource_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getSource_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getSource_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getSource_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getSource_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getSource_404`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listClips_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listClips_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listClips_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listClips_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getClip_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getClip_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getClip_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getClip_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getClip_404`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getTomorrowSchedule_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getTomorrowSchedule_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getTomorrowSchedule_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPost_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPost_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPost_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPost_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPost_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPost_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordSubmission_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordSubmission_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordSubmission_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordSubmission_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordSubmission_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordSubmission_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordAnalyticsCheckin_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordAnalyticsCheckin_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordAnalyticsCheckin_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordAnalyticsCheckin_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordAnalyticsCheckin_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordAnalyticsCheckin_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listDueAnalytics_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listDueAnalytics_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listDueAnalytics_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listDueAnalytics_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordPayoutEvent_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordPayoutEvent_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordPayoutEvent_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordPayoutEvent_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordPayoutEvent_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_recordPayoutEvent_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "CONFLICT",
            "EARNING_ALREADY_EXISTS",
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getFinanceSummary_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getFinanceSummary_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getFinanceSummary_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getFinanceSummary_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCostSummary_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCostSummary_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_getCostSummary_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_startPolliSession_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_startPolliSession_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_startPolliSession_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_startPolliSession_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_startPolliSession_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_startPolliSession_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPolliLiveSession_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPolliLiveSession_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPolliLiveSession_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPolliLiveSession_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPolliLiveSession_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_createPolliLiveSession_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "SESSION_NOT_ACTIVE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_queryPolli_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_queryPolli_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_queryPolli_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_queryPolli_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_queryPolli_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "COST_GOVERNOR_BLOCKED",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_queryPolli_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "SESSION_NOT_ACTIVE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_endPolliSession_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_endPolliSession_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_endPolliSession_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_endPolliSession_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_endPolliSession_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_endPolliSession_404`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_endPolliSession_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "SESSION_NOT_ACTIVE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listOwnerActions_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listOwnerActions_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listOwnerActions_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_listOwnerActions_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_resolveOwnerAction_401`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_INVALID",
            "AUTH_REQUIRED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_resolveOwnerAction_403`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "OWNER_FORBIDDEN"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_resolveOwnerAction_422`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REQUIRED",
            "VALIDATION_ERROR"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_resolveOwnerAction_429`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "RATE_LIMITED"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_resolveOwnerAction_503`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "AUTH_PROVIDER_UNAVAILABLE",
            "PROVIDER_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_resolveOwnerAction_404`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "NOT_FOUND"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `Error_resolveOwnerAction_409`
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": [
    "error"
  ],
  "properties": {
    "error": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "code",
        "message",
        "request_id",
        "details"
      ],
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "IDEMPOTENCY_KEY_REUSED",
            "INVALID_STATE_TRANSITION"
          ]
        },
        "message": {
          "type": "string",
          "minLength": 1,
          "maxLength": 500
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "details": {
          "type": "object",
          "additionalProperties": true
        }
      }
    }
  }
}
```

### `GenerationRequestedConstraintsV1`
```json
{
  "$ref": "jsonschema/generation.requested_constraints.v1.json"
}
```

### `CampaignRuleTypedValueV1`
```json
{
  "$ref": "jsonschema/campaign_rule.typed_value.v1.json"
}
```

### `OwnerActionResolutionV1`
```json
{
  "$ref": "jsonschema/owner_action.resolution.v1.json"
}
```

### `PostNativeAudioUsedV1`
```json
{
  "$ref": "jsonschema/post.native_audio_used.v1.json"
}
```

### `NativeAudioRecommendationV1`
```json
{
  "$ref": "jsonschema/audio_plan.native_recommendation.v1.json"
}
```

### `GenerationBudgetSnapshotV1`
```json
{
  "$ref": "jsonschema/generation.budget_snapshot.v1.json"
}
```

### `GenerationSelectedPlanV1`
```json
{
  "$ref": "jsonschema/generation.selected_plan.v1.json"
}
```

### `SourceRightsAuthorizedUsesV1`
```json
{
  "$ref": "jsonschema/source_rights.authorized_uses.v1.json"
}
```

### `SourceRightsPlatformLimitsV1`
```json
{
  "$ref": "jsonschema/source_rights.platform_limits.v1.json"
}
```

### `EditPlanV1`
```json
{
  "$ref": "jsonschema/edit_plan.v1.json"
}
```

### `RenderManifestV1`
```json
{
  "$ref": "jsonschema/render_manifest.v1.json"
}
```

## Round-7 semantic preconditions

- Campaign rule responses expose immutable `rule_snapshot_id`; the exact key-specific type and units are defined only in `HONOR_CAMPAIGN_RULE_REGISTRY.json`.
- `POST /v1/analytics/check-ins` accepts nullable `completed_views`, `completion_rate_ppm`, `average_watch_duration_ms`, and `follower_delta`; `watch_time_ms` is total cumulative watch time. Unavailable metrics remain null, never zero-filled.
- Post/schedule responses may surface an existing posting snapshot only when current rights revalidation permits recommendation; historical factual post records are not rewritten by later rights changes.
- V1 manual posting remains owner-operated; no endpoint automates native social publication.

## Round-8 cross-time API invariants

OpenAPI machine extensions point to `HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json` and `HONOR_ROUND8_INTEGRITY_FIXTURES.json`. The posting recommendation preserves disclosure `placement` (`CAPTION|VIDEO|BOTH|PROVIDER_SUBMISSION`) and provider-submission disclosure requirements; `submission_requirements.deadline_at` is the exact sealed campaign `deadline_at` mirror when KNOWN and null when NOT_APPLICABLE. VIDEO/BOTH disclosure is not reduced to caption text: it is represented in the edit plan and verified in render/QC. `EarningRecord.rule_snapshot_id` exposes the exact sealed campaign-rule provenance used by finance history. Internal paid-action timestamps are database-authored; caller timestamps cannot backdate authorization.

## Round-9 rule/QC/recommendation identity

V1 `edit_plan.v1.campaign_rule_snapshot_ids` is compatibility-shaped as an array but has exactly one item. It is the authoritative sealed rule snapshot for the edit/audio/clip/posting/render lineage. `render_manifest.v1` exposes `campaign_rule_snapshot_id` for the same identity. A client must not submit or reuse a plan under another campaign terms snapshot.

Posting recommendation revisions remain available before posting, but revision authorization is server/database time, not the clip's original creation time. The database records `recommendation_version` and `recommendation_revised_at` and rechecks current publication rights plus the current activated sealed campaign rule set. QC success is database-derived from `HONOR_QC_POLICY.json`, never trusted from a caller boolean.

## Round-10 posting and proof contract

Restriction compliance references are structured artifact references rather than arbitrary strings. The posting recommendation schema includes `posting_restriction_compliance`; when claim/content-bearing copy changes, the new recommendation version must carry fresh evidence for every active posting-consuming restriction. The proof is bound to the exact recommendation version and deterministic caption/title hash and must predate or equal the database-authored revision time.

Null `audio_plan_id` has exact API semantics: render-manifest audio-plan identity remains null and `render_safe_assets` is empty. Experiment-arm membership is immutable after insertion even while both possible parents are DRAFT.

## Round-11 pre-post proof and owner-review semantics

A material posting recommendation revision always advances the database-authored recommendation version. When the sealed rule set has a posting-consuming restriction, **every resulting version** must contain exact valid compliance evidence; hashtag-only, native-audio-only, disclosure/submission-only and evidence-only revisions do not inherit a prior-version proof. V1 chooses a fresh proof artifact for each recommendation version; unchanged caption/title may reuse the same deterministic subject hash but never the previous recommendation-version binding.

Owner review used as restriction evidence is a terminal database fact. Owner actions are created OPEN with DB-authored request time and can terminate once as RESOLVED or CANCELLED with DB-authored terminal time and immutable resolution hash. RESOLVED actions cannot be edited or reopened, so a restriction proof cannot rely on retroactive/backdated mutable human approval.

### Round 12 owner-action PRECOMMIT restriction review
For `RESTRICTION_COMPLIANCE`, owner resolution uses `review_phase=PRECOMMIT` and requires `target_version` in addition to campaign/rule/candidate/restriction, reserved target UUID, target type and subject SHA-256. The target edit-plan or initial clip need not exist when the owner resolves the review. The resolution only becomes usable when the later committed edit-plan/recommendation version exactly matches the reserved target UUID, version, subject hash and lineage, and the DB-authored commit/revision follows the immutable owner resolution/proof.
