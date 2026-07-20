# ─────────────────────────────────────────────
# Stage 1 - Build JS bundle
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /project

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
        use: {
          loader: 'babel-loader'
        }
      }
    ]
  }
};
EOF

RUN cat > babel.config.json <<'EOF'
{
  "presets": [
    "@babel/preset-env",
    "@babel/preset-react"
  ]
}
EOF

RUN mkdir -p src && cat > src/index.js <<'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';

function App() {
  return <h1>Hello from Empty App!</h1>;
}

const root = ReactDOM.createRoot(
  document.getElementById('root')
);

root.render(<App />);
EOF

RUN npm install && npm run build


# ─────────────────────────────────────────────
# Stage 2 - Prepare output payload
# ─────────────────────────────────────────────
FROM alpine:3.19

RUN mkdir -p /output

COPY --from=builder \
    /project/dist/bundle.js \
    /output/payload
