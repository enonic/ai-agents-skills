# Build System

## Vanilla (JavaScript) Setup

### build.gradle

```gradle
plugins {
    id 'com.enonic.xp.app' version '3.6.2'
}

app {
    name = "${appName}"
    displayName = "${appDisplayName}"
    vendorName = "${vendorName}"
    vendorUrl = "${vendorUrl}"
    systemVersion = "${xpVersion}"
}

dependencies {
    implementation "com.enonic.xp:core-api:${xpVersion}"
    implementation "com.enonic.xp:portal-api:${xpVersion}"
    include "com.enonic.xp:lib-content:${xpVersion}"
    include "com.enonic.xp:lib-portal:${xpVersion}"
    include "com.enonic.lib:lib-thymeleaf:2.1.1"
}

tasks.register('dev', Exec) {
    if (org.gradle.internal.os.OperatingSystem.current().isWindows()) {
        commandLine 'cmd', '/c', 'gradlew.bat', 'deploy', '-t'
    } else {
        commandLine './gradlew', 'deploy', '-t'
    }
}

repositories {
    mavenLocal()
    mavenCentral()
    xp.enonicRepo()
}
```

> XP 8 apps use plugin version 4.x: `id 'com.enonic.xp.app' version '4.0.0'`

### gradle.properties

```properties
group = com.example
projectName = my-app
version = 1.0.0-SNAPSHOT
appDisplayName = My Application
appName = com.example.my-app
vendorName = Acme Inc
vendorUrl = https://example.com
xpVersion = 7.16.1
```

### settings.gradle

```gradle
rootProject.name = projectName
```

### Available XP Libraries

Uncomment as needed in `dependencies`:

```gradle
// Core platform libraries
include "com.enonic.xp:lib-admin:${xpVersion}"
include "com.enonic.xp:lib-auth:${xpVersion}"
include "com.enonic.xp:lib-content:${xpVersion}"
include "com.enonic.xp:lib-context:${xpVersion}"
include "com.enonic.xp:lib-event:${xpVersion}"
include "com.enonic.xp:lib-i18n:${xpVersion}"
include "com.enonic.xp:lib-io:${xpVersion}"
include "com.enonic.xp:lib-mail:${xpVersion}"
include "com.enonic.xp:lib-node:${xpVersion}"
include "com.enonic.xp:lib-portal:${xpVersion}"
include "com.enonic.xp:lib-project:${xpVersion}"
include "com.enonic.xp:lib-repo:${xpVersion}"
include "com.enonic.xp:lib-task:${xpVersion}"
include "com.enonic.xp:lib-websocket:${xpVersion}"

// Third-party libraries from Enonic Market
include "com.enonic.lib:lib-thymeleaf:2.1.1"
include "com.enonic.lib:lib-mustache:2.1.1"
include "com.enonic.lib:lib-http-client:3.2.2"
include "com.enonic.lib:lib-router:3.1.0"
include "com.enonic.lib:lib-cache:2.2.0"
include "com.enonic.lib:lib-static:1.0.3"
```

**`implementation`** -- compile-time dependency (API access)
**`include`** -- bundled into the JAR (runtime dependency)

### Build Commands

```bash
./gradlew build          # Build JAR
./gradlew deploy         # Build and deploy to sandbox
./gradlew deploy -t      # Deploy with continuous rebuild (watch mode)
./gradlew clean          # Clean build artifacts
```

## TypeScript Setup (tsup)

### build.gradle

```gradle
plugins {
    id 'com.enonic.xp.app' version '3.6.2'
    id 'com.github.node-gradle.node' version '7.1.0'
}

app {
    name = "${appName}"
    displayName = "${appDisplayName}"
    vendorName = "${vendorName}"
    vendorUrl = "${vendorUrl}"
    systemVersion = "${xpVersion}"
}

dependencies {
    // Same XP libraries as vanilla -- uncomment as needed
}

repositories {
    mavenLocal()
    mavenCentral()
    xp.enonicRepo()
}

node {
    download = true
    version = '22.15.1'
}

processResources {
    exclude '**/.gitkeep'
    exclude '**/*.json'
    exclude '**/*.ts'
    exclude '**/*.tsx'
}

tasks.register('dev', Exec) {
    if (org.gradle.internal.os.OperatingSystem.current().isWindows()) {
        commandLine 'cmd', '/c', 'gradlew.bat', 'deploy', '-t'
    } else {
        commandLine './gradlew', 'deploy', '-t'
    }
}

tasks.register('npmBuild', NpmTask) {
    args = ['run', '--silent', 'build']
    dependsOn npmInstall
    environment = [
        'FORCE_COLOR': 'true',
        'LOG_LEVEL_FROM_GRADLE': gradle.startParameter.logLevel.toString(),
        'NODE_ENV': project.hasProperty('dev') || project.hasProperty('development')
            ? 'development' : 'production'
    ]
    inputs.dir 'src/main/resources'
    outputs.dir 'build/resources/main'
    outputs.upToDateWhen { false }
}

jar.dependsOn npmBuild

tasks.register('npmCheck', NpmTask) {
    dependsOn npmInstall
    args = ['run', 'check']
    environment = ['FORCE_COLOR': 'true']
}

check.dependsOn npmCheck

tasks.register('npmTest', NpmTask) {
    args = ['run', 'test']
    dependsOn npmInstall
    environment = ['FORCE_COLOR': 'true']
    inputs.dir 'src/jest'
    outputs.dir 'coverage'
    outputs.upToDateWhen { false }
}

test.dependsOn npmTest

tasks.withType(Copy).configureEach {
    includeEmptyDirs = false
}
```

### package.json

Enonic projects typically use **pnpm**. The scripts below work with both npm and pnpm.

```json
{
    "private": true,
    "scripts": {
        "build": "concurrently -c auto -g --timings npm:build:*",
        "build:assets": "node tsup/build.js src/main/resources/assets build/resources/main/assets",
        "build:server": "node tsup/build.js src/main/resources build/resources/main",
        "check": "concurrently -c auto -g --timings npm:check:types npm:lint",
        "check:types": "concurrently --kill-others-on-fail -g -r --timings npm:check:types:*",
        "check:types:assets": "node tsup/check.js src/main/resources/assets",
        "check:types:server": "node tsup/check.js src/main/resources src/main/resources/assets",
        "lint": "eslint --cache",
        "test": "jest --no-cache"
    },
    "devDependencies": {
        "@enonic-types/core": "^7.16.1",
        "@enonic-types/global": "^7.16.1",
        "@enonic-types/lib-content": "^7.16.1",
        "@enonic-types/lib-portal": "^7.16.1",
        "@swc/core": "^1.15.3",
        "concurrently": "^9.2.1",
        "eslint": "^9.39.1",
        "tsup": "^8.5.1",
        "typescript": "^5.9.3",
        "typescript-eslint": "^8.47.0"
    }
}
```

Add `@enonic-types/lib-*` packages matching the XP libs you use in Gradle.

### TypeScript Configuration (Three Layers)

**Root `tsconfig.json`** -- for build scripts (tsup/, etc.):

```json
{
    "include": ["**/*.ts"],
    "exclude": ["**/*.d.ts", "src/**/*.*"],
    "compilerOptions": {
        "lib": ["es2023"],
        "types": ["node"]
    }
}
```

**`src/main/resources/tsconfig.json`** -- server-side controllers:

```json
{
    "include": ["**/*.ts"],
    "exclude": ["**/*.d.ts", "assets/**/*.*"],
    "compilerOptions": {
        "paths": {
            "/lib/xp/*": ["../../../node_modules/@enonic-types/lib-*"],
            "/*": ["./*"]
        },
        "skipLibCheck": true,
        "types": ["@enonic-types/global"]
    }
}
```

The `paths` mapping lets you write `import { getContent } from '/lib/xp/content'` and get proper type checking.

**`src/main/resources/assets/tsconfig.json`** -- client-side assets:

```json
{
    "include": ["./**/*.ts", "./**/*.tsx"],
    "exclude": ["./**/*.d.ts"],
    "compilerOptions": {
        "lib": ["DOM"]
    }
}
```

### tsup Configuration

**`tsup.config.ts`**:

```ts
import type { Options } from './tsup';
import { defineConfig } from 'tsup';
import { DIR_DST, DIR_DST_ASSETS } from './tsup/constants';

export default defineConfig(async (options: Options) => {
    if (options.d === DIR_DST) {
        return import('./tsup/server').then(m => m.default());
    }
    if (options.d === DIR_DST_ASSETS) {
        return import('./tsup/client').then(m => m.default());
    }
    throw new Error(`Unconfigured directory:${options.d}!`);
});
```

**`tsup/constants.ts`**:

```ts
export const AND_BELOW = '**';
export const DIR_DST = 'build/resources/main';
export const DIR_DST_ASSETS = `${DIR_DST}/assets`;
export const DIR_SRC = 'src/main/resources';
export const DIR_SRC_ASSETS = `${DIR_SRC}/assets`;
```

**`tsup/server.ts`** -- server bundle (controllers, services, tasks):

```ts
import type { Options } from '.';
import { globSync } from 'glob';
import { AND_BELOW, DIR_SRC, DIR_SRC_ASSETS } from './constants';
import { dict } from './dict';

export default function buildServerConfig(): Options {
    const FILES_SERVER = globSync(
        `${DIR_SRC}/${AND_BELOW}/*.{ts,js}`,
        { absolute: false, posix: true,
          ignore: globSync(`${DIR_SRC_ASSETS}/${AND_BELOW}/*.{ts,js}`,
                           { absolute: false, posix: true }) }
    );

    const SERVER_JS_ENTRY = dict(FILES_SERVER.map(k => [
        k.replace(`${DIR_SRC}/`, '').replace(/\.[^.]*$/, ''), k
    ]));

    return {
        bundle: true,
        dts: false,
        entry: SERVER_JS_ENTRY,
        esbuildOptions(options) {
            options.mainFields = ['module', 'main'];
        },
        external: [
            /^\/lib\/xp\//,
            '/lib/thymeleaf',
            '/lib/mustache',
            '/lib/cache',
            '/lib/http-client',
            '/lib/router',
        ],
        format: 'cjs',
        minify: false,
        platform: 'neutral',
        shims: false,
        splitting: true,
        sourcemap: false,
        target: 'es5',
        tsconfig: `${DIR_SRC}/tsconfig.json`,
    };
}
```

Key: `external` must list all XP libraries so they are NOT bundled (resolved at runtime by XP).

**`tsup/client.ts`** -- client bundle (browser assets):

```ts
import type { Options } from '.';
import { globSync } from 'glob';
import { AND_BELOW, DIR_SRC_ASSETS } from './constants';
import { dict } from './dict';

export default function buildAssetConfig(): Options {
    const FILES_ASSETS = globSync(
        `${DIR_SRC_ASSETS}/${AND_BELOW}/*.{tsx,ts,jsx,js}`,
        { posix: true }
    );

    const ASSETS_JS_ENTRY = dict(FILES_ASSETS.map(k => [
        k.replace(`${DIR_SRC_ASSETS}/`, '').replace(/\.[^.]*$/, ''), k
    ]));

    return {
        bundle: true,
        dts: false,
        entry: ASSETS_JS_ENTRY,
        format: ['esm'],
        minify: process.env.NODE_ENV !== 'development',
        platform: 'browser',
        splitting: true,
        sourcemap: process.env.NODE_ENV !== 'development',
        tsconfig: `${DIR_SRC_ASSETS}/tsconfig.json`,
    };
}
```

## TypeScript Setup (Webpack Alternative)

Some complex apps use Webpack + SWC instead of tsup:

### webpack.config.js

```js
const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

const isProd = process.env.NODE_ENV === 'production';

module.exports = {
    context: path.join(__dirname, '/src/main/resources/assets'),
    entry: {
        'js/app': './js/app.ts',
        'styles/main': './styles/main.less'
    },
    output: {
        path: path.join(__dirname, '/build/resources/main/assets'),
        filename: './[name].js',
    },
    module: {
        rules: [
            {
                test: /\.ts$/,
                use: [{
                    loader: 'swc-loader',
                    options: { sourceMaps: isProd ? false : 'inline' }
                }]
            },
            {
                test: /\.less$/,
                use: [
                    MiniCssExtractPlugin.loader,
                    'css-loader',
                    'postcss-loader',
                    'less-loader'
                ]
            }
        ]
    },
    plugins: [new MiniCssExtractPlugin()],
    resolve: { extensions: ['.ts', '.js'] }
};
```

For Webpack-based TS apps, use `.swcrc`:

```json
{
    "jsc": {
        "parser": { "syntax": "typescript", "dynamicImport": true },
        "target": "es2018",
        "keepClassNames": true
    },
    "module": { "type": "commonjs" }
}
```

## Vite (Alternative)

Some XP 8 apps use Vite instead of tsup or webpack. Vite provides faster builds and HMR.
The configuration pattern is similar to webpack but uses `vite.config.ts`.
Vite is commonly used for admin tools with complex frontends.

## Build Commands

### Vanilla

```bash
./gradlew build          # Build JAR
./gradlew deploy         # Build + deploy to sandbox
./gradlew deploy -t      # Watch mode
./gradlew clean          # Clean
```

### TypeScript

```bash
./gradlew build          # Full build (npm + gradle)
./gradlew deploy         # Build + deploy
./gradlew deploy -t      # Watch mode

# npm/pnpm scripts (run directly during development)
npm run build            # Compile TS → JS
npm run check            # Type-check + lint
npm run test             # Run tests
npm run lint             # ESLint only
```

Replace `npm` with `pnpm` if using pnpm (recommended for Enonic projects).

## Adding Dependencies

### XP Library (Gradle)

1. Add to `build.gradle`:
```gradle
include "com.enonic.xp:lib-auth:${xpVersion}"
```

2. For TS: Add types to `package.json`:
```json
"@enonic-types/lib-auth": "^7.16.1"
```

3. Add to tsup server config `external` list:
```ts
external: [/^\/lib\/xp\//, '/lib/auth']
```

### Market Library (Gradle)

```gradle
include "com.enonic.lib:lib-http-client:3.2.2"
```

### npm Package (Client-side Only)

```bash
npm install --save-dev some-package
```

Client-side npm packages are bundled by tsup/webpack into assets. Server-side npm packages generally cannot be used -- use XP libraries instead.

## Java Services (Optional)

For complex logic, add Java services in `src/main/java/`:

```java
package com.example.myapp;

import org.osgi.service.component.annotations.Component;

@Component(immediate = true)
public class MyService {
    public String process(String input) {
        // Complex Java logic
        return result;
    }
}
```

Access from JS/TS controllers:

```js
var myService = __.newBean('com.example.myapp.MyService');
var result = myService.process('input');
```
