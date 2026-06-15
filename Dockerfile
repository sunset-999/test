# ─────────────────────────────────────────────
# Stage 1 – Build the JS bundle
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /project

# ── Create a minimal React app with webpack ──
RUN cat > package.json <<'EOF'
{
  "name": "empty-app",
  "version": "1.0.0",
  "scripts": {
    "build": "webpack --mode production"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "webpack": "^5.91.0",
    "webpack-cli": "^5.1.4",
    "babel-loader": "^9.1.3",
    "@babel/core": "^7.24.0",
    "@babel/preset-env": "^7.24.0",
    "@babel/preset-react": "^7.23.3"
  }
}
EOF

RUN cat > webpack.config.js <<'EOF'
const path = require('path');
module.exports = {
  entry: './src/index.js',
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
  },
  module: {
    rules: [
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        use: { loader: 'babel-loader' }
      }
    ]
  }
};
EOF

RUN cat > babel.config.json <<'EOF'
{
  "presets": ["@babel/preset-env", "@babel/preset-react"]
}
EOF

RUN mkdir -p src && cat > src/index.js <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';

function App() {
  return <h1>Hello from Empty App!</h1>;
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
EOF

# ── Install deps & build ──────────────────────
RUN npm install && npm run build

# ─────────────────────────────────────────────
# Stage 2 – Upload bundle.js via HTTP POST
# ─────────────────────────────────────────────
FROM alpine:3.19

RUN apk add --no-cache curl

COPY --from=builder /project/dist/bundle.js /bundle/bundle.js

# ╔══════════════════════════════════════════════════════════════════╗
# ║                  📡  UPLOAD CONFIGURATION                       ║
# ║                                                                  ║
# ║  UPLOAD_URL   → The full HTTP endpoint that will receive the JS  ║
# ║                 Example: http://192.168.1.10:3000/upload         ║
# ║                                                                  ║
# ║  UPLOAD_TOKEN → Bearer token for Authorization header.           ║
# ║                 Leave it empty ("") if your server has no auth.  ║
# ║                 Example: my-secret-token-123                     ║
# ║                                                                  ║
# ║  ⚠️  CHANGE THE VALUES BELOW BEFORE BUILDING THE IMAGE           ║
# ╚══════════════════════════════════════════════════════════════════╝
ENV UPLOAD_URL="http://192.168.1.163:3000/upload" \
    UPLOAD_TOKEN=""

CMD ["sh", "-c", "\
  if [ -z \"$UPLOAD_URL\" ]; then \
    echo '❌ UPLOAD_URL is not set.'; exit 1; \
  fi; \
  echo '📦 Uploading bundle.js to '$UPLOAD_URL' ...'; \
  HTTP_CODE=$(curl -s -o /tmp/response.txt -w '%{http_code}' \
    ${UPLOAD_TOKEN:+-H \"Authorization: Bearer $UPLOAD_TOKEN\"} \
    -F \"file=@/bundle/bundle.js;type=application/javascript\" \
    \"$UPLOAD_URL\"); \
  echo \"Server responded: $HTTP_CODE\"; \
  cat /tmp/response.txt; \
  if [ \"$HTTP_CODE\" -ge 200 ] && [ \"$HTTP_CODE\" -lt 300 ]; then \
    echo '✅ Upload successful!'; \
  else \
    echo '❌ Upload failed.'; exit 1; \
  fi \
"]
