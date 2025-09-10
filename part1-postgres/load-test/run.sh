
#!/bin/bash

echo "Send 20 requests to http://localhost:8080/data..."
for i in {1..20}; do
  curl -s http://localhost:8080/data && echo ""
  sleep 0.5
done
