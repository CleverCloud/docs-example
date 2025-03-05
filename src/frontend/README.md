## Run without Docker

### Locally

```shell
cd src/frontend
yarn install
yarn app:build
yarn app:start
```

This starts and configure the app in different workspaces.

### Deploy on Clever Cloud

## Environment variables when deploying from `src/frontend`

```shell
CC_NODE_BUILD_TOOL="yarn"
CC_PRE_BUILD_HOOK="yarn install --frozen-lockfile && yarn app:build"
CC_RUN_COMMAND="yarn app:start"
CC_TROUBLESHOOT="true"
NEXT_PUBLIC_API_ORIGIN="backend url"
NEXT_PUBLIC_SW_DEACTIVATED="true"
NODE_OPTIONS="--max-old-space-size=4096"
```

## Environment variables when deploying from root

```shell
APP_FOLDER="./src/frontend"
CC_NODE_BUILD_TOOL="yarn"
CC_PRE_BUILD_HOOK="cd ./src/frontend && yarn install --frozen-lockfile && yarn app:build"
CC_RUN_COMMAND="cd ./src/frontend && yarn app:start"
CC_TROUBLESHOOT="true"
NEXT_PUBLIC_API_ORIGIN="<backend-url>"
NEXT_PUBLIC_SW_DEACTIVATED="true"
NODE_OPTIONS="--max-old-space-size=4096"
```
