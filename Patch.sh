kubectl patch virtualservice my-vs \
  -n myns \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/http/-",
      "value": {
        "match": [
          {
            "uri": {
              "prefix": "/api"
            }
          }
        ],
        "rewrite": {
          "uri": "/"
        },
        "route": [
          {
            "destination": {
              "host": "api-service",
              "port": {
                "number": 80
              }
            }
          }
        ]
      }
    }
  ]'
