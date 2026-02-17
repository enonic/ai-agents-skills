# Controllers

## Controller Basics

Controllers are JavaScript files that export HTTP method handlers. XP resolves `<name>.js` next to `<name>.xml`. In TypeScript apps, source `.ts` files are compiled to `.js` by tsup or webpack.

### JS Pattern

```js
var portal = require('/lib/xp/portal');

exports.get = function(req) {
    return {
        status: 200,
        contentType: 'text/html',
        body: '<h1>Hello</h1>'
    };
};

exports.post = function(req) {
    var body = JSON.parse(req.body);
    return {
        status: 200,
        contentType: 'application/json',
        body: { success: true }
    };
};
```

### TS Pattern

```ts
import type { Request, Response } from '/lib/xp/portal';

export function get(req: XP.Request): XP.Response {
    return {
        status: 200,
        contentType: 'text/html',
        body: '<h1>Hello</h1>'
    };
}

export function post(req: XP.Request): XP.Response {
    const body = JSON.parse(req.body);
    return {
        status: 200,
        contentType: 'application/json',
        body: { success: true }
    };
}
```

### Request Object

```ts
interface Request {
    method: string;           // 'GET', 'POST', etc.
    scheme: string;           // 'http' or 'https'
    host: string;             // hostname
    port: number;             // port number
    path: string;             // request path
    url: string;              // full URL
    body: string;             // request body (string)
    params: Record<string, string>;   // query parameters
    headers: Record<string, string>;  // HTTP headers
    cookies: Record<string, string>;  // request cookies
    contentType: string;      // request content type
    webSocket: boolean;       // true if WebSocket upgrade
    mode: string;             // 'edit', 'preview', 'live', 'inline'
    branch: string;           // 'draft' or 'master'
    locales: string[];        // accepted locales
}
```

### Response Object

```ts
interface Response {
    status?: number;          // HTTP status (default 200)
    contentType?: string;     // MIME type
    body?: string | object;   // string or object (auto-JSON)
    headers?: Record<string, string>;
    cookies?: Record<string, string | CookieConfig>;
    redirect?: string;        // redirect URL
    postProcess?: boolean;    // enable post-processing
    applyFilters?: boolean;   // apply response filters
    pageContributions?: {     // inject into page head/body
        headBegin?: string[];
        headEnd?: string[];
        bodyBegin?: string[];
        bodyEnd?: string[];
    };
    webSocket?: {             // WebSocket upgrade response
        data?: Record<string, unknown>;
        subProtocols?: string[];
    };
}
```

## Service Controllers

Services provide HTTP endpoints independent of content. Located in `services/<name>/`.

### Location and URL

- Files: `services/<name>/<name>.xml` + `<name>.js`
- URL: `/_/service/<app-name>/<service-name>`
- In controllers: `portal.serviceUrl({ service: 'my-service' })`

### Descriptor (`services/data/data.xml`)

```xml
<service>
  <allow>
    <principal>role:system.authenticated</principal>
  </allow>
</service>
```

Omit `<allow>` for public access. The descriptor XML is optional -- without it, the service is accessible to everyone.

### Controller (`services/data/data.js`)

```js
var contentLib = require('/lib/xp/content');

exports.get = function(req) {
    var type = req.params.type;
    if (!type) {
        return { status: 400, body: { error: 'Missing type parameter' } };
    }

    var result = contentLib.query({
        contentTypes: [app.name + ':' + type],
        count: 10
    });

    return {
        status: 200,
        contentType: 'application/json',
        body: { items: result.hits, total: result.total }
    };
};
```

### TS Controller (`services/data/data.ts`)

```ts
import { query } from '/lib/xp/content';

export function get(req: XP.Request): XP.Response {
    const type = req.params.type;
    if (!type) {
        return { status: 400, body: { error: 'Missing type parameter' } };
    }

    const result = query({
        contentTypes: [`${app.name}:${type}`],
        count: 10
    });

    return {
        status: 200,
        contentType: 'application/json',
        body: { items: result.hits, total: result.total }
    };
}
```

### Common Service Patterns

#### Config Service

Admin tools often expose a config service that returns app configuration as JSON. The frontend fetches this on initialization instead of embedding config in the HTML.

**`services/config/config.js`**:

```js
var admin = require('/lib/xp/admin');
var portal = require('/lib/xp/portal');

exports.get = function(req) {
    return {
        status: 200,
        contentType: 'application/json',
        body: {
            adminUrl: admin.getBaseUri(),
            appId: app.name,
            assetsUri: portal.assetUrl({ path: '' }),
            toolUri: admin.getToolUrl(app.name, 'main')
        }
    };
};
```

The admin tool HTML template passes the config service URL to the frontend via a data attribute:

```html
<script defer src="{{assetsUri}}/js/app.js"
        data-config-service-url="{{configServiceUrl}}"></script>
```

Frontend reads it on init:

```js
var configUrl = document.currentScript.getAttribute('data-config-service-url');
fetch(configUrl).then(function(res) { return res.json(); }).then(initApp);
```

#### Config Injection (XP 8+)

XP 8 embeds config as inline JSON in the HTML instead of fetching it from a service. This eliminates the extra HTTP request and makes config available synchronously.

**Controller** — serialize config and inject into the template:

```js
var config = {
    adminUrl: admin.getBaseUri(),
    appId: app.name,
    assetsUri: portal.assetUrl({ path: '' })
};

var params = {
    configScriptId: app.name + '.config',
    configAsJson: JSON.stringify(config).replace(/<(\/?script|!--)/gi, '\\u003C$1')
};
```

The `.replace()` call prevents XSS by escaping `<script>`, `</script>`, and `<!--` sequences within the JSON string.

**HTML template**:

```html
<script type="application/json" id="{{configScriptId}}">{{{configAsJson}}}</script>
<script defer src="{{assetsUri}}/js/bundle.js"
        data-config-script-id="{{configScriptId}}"></script>
```

**Frontend** — read config from the DOM:

```js
var scriptId = document.currentScript.getAttribute('data-config-script-id');
var config = JSON.parse(document.getElementById(scriptId).textContent);
```

#### i18n Service

A dedicated service returns localized phrase bundles as JSON, enabling client-side localization without server-side rendering of each string.

**`services/i18n/i18n.js`**:

```js
var i18nLib = require('/lib/xp/i18n');

exports.get = function(req) {
    var locales = req.params.locale ? [req.params.locale] : [];

    return {
        status: 200,
        contentType: 'application/json',
        body: i18nLib.getPhrases(locales, ['i18n/phrases'])
    };
};
```

`getPhrases(locales, bundles)` returns all key-value pairs from the specified bundles as a flat object. The frontend stores these and uses them for UI text lookup.

> **XP 8+**: Implement as a Universal API at `apis/i18n/i18n.js` with an `apis/i18n/i18n.xml` descriptor. The controller code is identical. Use `apiUrl({ api: 'i18n' })` for URL resolution, and declare `<api>i18n</api>` in the admin tool descriptor's `<apis>` element.

## API Controllers (Universal API — XP 8+)

Universal APIs replace services as the recommended way to expose HTTP endpoints in XP 8+. Services remain valid for XP 7. Located in `apis/<name>/`.

### Location and URL

- Files: `apis/<name>/<name>.xml` + `<name>.js`
- URL: `/api/<app-name>/<api-name>/`
- In controllers: `portal.apiUrl({ api: 'my-api' })`
- Cross-app: `portal.apiUrl({ api: 'other-api', application: 'com.other.app' })`

### Descriptor (`apis/content/content.xml`)

```xml
<api xmlns="urn:enonic:xp:model:1.0">
  <allow>
    <principal>role:system.authenticated</principal>
  </allow>
</api>
```

Omit `<allow>` for public access. The descriptor XML is optional — without it, the API is accessible to everyone.

### JS Controller (`apis/content/content.js`)

```js
var contentLib = require('/lib/xp/content');

exports.get = function(req) {
    var contentId = req.params.contentId;
    if (!contentId) {
        return { status: 400, contentType: 'text/plain', body: 'Missing contentId' };
    }

    var content = contentLib.get({ key: contentId });
    return {
        status: 200,
        contentType: 'application/json',
        body: content
    };
};
```

### TS Controller (`apis/content/content.ts`)

```ts
import { get as getContent } from '/lib/xp/content';

export function get(req: XP.Request): XP.Response {
    const contentId = req.params.contentId;
    if (!contentId) {
        return { status: 400, contentType: 'text/plain', body: 'Missing contentId' };
    }

    const content = getContent({ key: contentId });
    return {
        status: 200,
        contentType: 'application/json',
        body: content
    };
}
```

### Using `apiUrl()`

```ts
import { apiUrl } from '/lib/xp/portal';

// Same-app API
const url = apiUrl({ api: 'my-api' });

// Cross-app API
const externalUrl = apiUrl({ api: 'their-api', application: 'com.other.app' });

// API with sub-path (useful for REST-style endpoints)
const installUrl = apiUrl({ api: 'my-api', path: 'sub/endpoint' });
```

### APIs in Admin Tool Descriptors

Admin tools must declare which APIs they use via the `<apis>` element:

```xml
<tool xmlns="urn:enonic:xp:model:1.0">
  <display-name>My Tool</display-name>
  <allow>
    <principal>role:system.authenticated</principal>
  </allow>
  <apis>
    <api>my-api</api>
    <api>admin:widget</api>
    <api>com.other.app:their-api</api>
  </apis>
</tool>
```

Unqualified names (e.g. `my-api`) refer to APIs in the same app. Use `<app-key>:<api-name>` for cross-app references. The `<apis>` element is XP 8+ only. XP 7 admin tools do not declare APIs — services are implicitly available.

### System APIs (XP 8+)

XP provides built-in admin APIs available to all admin tools:
- `admin:widget` -- launcher widget
- `admin:event` -- server-sent events for real-time updates
- `admin:status` -- connection health check

Declare them in `<apis>` alongside your custom APIs. No descriptor files needed for system APIs.

### APIs vs Services

| | APIs (XP 8+) | Services (XP 7+) |
|---|---|---|
| Location | `apis/<name>/` | `services/<name>/` |
| URL pattern | `/api/<app>/<name>/` | `/_/service/<app>/<name>` |
| URL helper | `apiUrl({ api })` | `serviceUrl({ service })` |
| Access control | `<allow>` in descriptor | `<allow>` in descriptor |
| Admin tool integration | Declared via `<apis>` | Always available |

## Task Controllers

Background tasks with optional parameters. Located in `tasks/<name>/`.

### Descriptor (`tasks/import-data/import-data.xml`)

```xml
<task xmlns="urn:enonic:xp:model:1.0">
  <description>Import data from external source</description>
  <form>
    <input name="source" type="TextLine">
      <label>Source URL</label>
      <occurrences minimum="1" maximum="1"/>
    </input>
    <input name="dryRun" type="Checkbox">
      <label>Dry Run</label>
    </input>
  </form>
</task>
```

### JS Controller (`tasks/import-data/import-data.js`)

```js
exports.run = function(params) {
    log.info('Starting import from: ' + params.source);

    var items = fetchData(params.source);

    if (params.dryRun) {
        log.info('Dry run: would import ' + items.length + ' items');
        return;
    }

    for (var i = 0; i < items.length; i++) {
        importItem(items[i]);
    }

    log.info('Import complete: ' + items.length + ' items');
};
```

### TS Controller (`tasks/import-data/import-data.ts`)

```ts
interface ImportParams {
    source: string;
    dryRun?: boolean;
}

export function run(params: ImportParams): void {
    log.info(`Starting import from: ${params.source}`);

    const items = fetchData(params.source);

    if (params.dryRun) {
        log.info(`Dry run: would import ${items.length} items`);
        return;
    }

    items.forEach(item => importItem(item));
    log.info(`Import complete: ${items.length} items`);
}
```

### Submitting Tasks

From another controller:

```js
var taskLib = require('/lib/xp/task');

var taskId = taskLib.submitTask({
    descriptor: 'import-data',
    config: {
        source: 'https://api.example.com/data',
        dryRun: false
    }
});
```

## Admin Tool Controllers

Admin tools provide full-page admin interfaces. Located in `admin/tools/<name>/`.

### Descriptor (`admin/tools/dashboard/dashboard.xml`)

```xml
<tool xmlns="urn:enonic:xp:model:1.0">
  <display-name>My Dashboard</display-name>
  <description>Application dashboard</description>
  <allow>
    <principal>role:system.admin</principal>
    <principal>role:system.user.admin</principal>
  </allow>
  <apis>
    <api>my-api</api>
  </apis>
</tool>
```

### Controller (`admin/tools/dashboard/dashboard.js`)

```js
var admin = require('/lib/xp/admin');
var mustache = require('/lib/mustache');
var portal = require('/lib/xp/portal');

exports.get = function(req) {
    var view = resolve('./dashboard.html');
    var params = {
        adminAssetsUri: admin.getAssetsUri(),
        assetsUri: portal.assetUrl({ path: '' }),
        appName: app.name,
        toolUrl: admin.getToolUrl(app.name, 'dashboard'),
        homeToolUrl: admin.getHomeToolUrl()
    };

    return {
        contentType: 'text/html',
        body: mustache.render(view, params)
    };
};
```

**Admin lib functions** (`/lib/xp/admin`):
- `getAssetsUri()` -- base URL for admin UI assets
- `getBaseUri()` -- base URL for admin console
- `getLauncherPath()` -- URL to the admin launcher script
- `getLocales()` -- active locales for the admin session
- `getToolUrl(app, tool)` -- URL for a specific admin tool
- `getHomeToolUrl()` -- URL for the admin home tool
- `widgetUrl({ application, widget, params })` -- URL for an admin widget

In admin tools where portal context isn't available, use `/lib/enonic/asset` instead of `/lib/xp/portal` for asset URLs:

```js
var assetLib = require('/lib/enonic/asset');
var assetsUri = assetLib.assetUrl({ path: '' });
```

### HTML Template

Admin tools render an HTML page that loads the launcher, CSS, JS bundle, and passes config:

**`admin/tools/dashboard/dashboard.html`** (Mustache):

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/png" href="{{assetsUri}}/icons/favicon-32.png" sizes="32x32">
    <link rel="stylesheet" href="{{assetsUri}}/styles/main.css">
</head>
<body>
    <script async src="{{launcherPath}}" data-config-theme="dark"></script>
    <script defer src="{{assetsUri}}/js/app.js"
            data-config-service-url="{{configServiceUrl}}"></script>
</body>
</html>
```

The controller provides the template variables:

```js
var params = {
    assetsUri: portal.assetUrl({ path: '' }),
    launcherPath: admin.getLauncherPath(),
    configServiceUrl: portal.serviceUrl({ service: 'config' })
};
```

- **Launcher script** (`async`) — loads the shared admin launcher UI (top bar, navigation)
- **App bundle** (`defer`) — the app's own JS; `data-config-service-url` tells it where to fetch config
- **Favicon** — include multiple sizes (32x32, 128x128) and platform variants (iOS, Android) as needed

### HTML Template (XP 8+)

XP 8 replaces the launcher script with `widgetUrl()` and delivers config as inline JSON instead of a service fetch:

**`admin/tools/dashboard/dashboard.html`** (Mustache):

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/png" href="{{assetsUri}}/icons/favicon-32.png" sizes="32x32">
    <link rel="stylesheet" href="{{adminAssetsUri}}/styles/lib.css">
    <link rel="stylesheet" href="{{assetsUri}}/styles/main.css">
    <script src="{{adminAssetsUri}}/js/lib.js"></script>
</head>
<body>
    <script type="application/json" id="{{configScriptId}}">{{{configAsJson}}}</script>
    <script defer src="{{assetsUri}}/js/bundle.js"
            data-config-script-id="{{configScriptId}}"></script>
</body>
</html>
```

The controller provides the template variables:

```js
var admin = require('/lib/xp/admin');
var portal = require('/lib/xp/portal');

var config = {
    adminUrl: admin.getBaseUri(),
    appId: app.name,
    assetsUri: portal.assetUrl({ path: '' }),
    launcherUrl: admin.widgetUrl({ application: 'admin', widget: 'widget' }),
    toolUri: admin.getToolUrl(app.name, 'dashboard')
};

var params = {
    adminAssetsUri: admin.getAssetsUri(),
    assetsUri: portal.assetUrl({ path: '' }),
    configScriptId: app.name + '.config',
    configAsJson: JSON.stringify(config).replace(/<(\/?script|!--)/gi, '\\u003C$1')
};
```

Frontend reads config synchronously from the DOM:

```js
var scriptId = document.currentScript.getAttribute('data-config-script-id');
var config = JSON.parse(document.getElementById(scriptId).textContent);
initApp(config);
```

Key differences from XP 7:
- **Admin common assets** — `lib.css` and `lib.js` loaded from `adminAssetsUri` (shared admin UI framework)
- **Inline JSON config** — embedded in a `<script type="application/json">` block, no extra HTTP request
- **Launcher via `widgetUrl()`** — replaces `getLauncherPath()` + `<script async>`
- **XSS protection** — `replace(/<(\/?script|!--)/gi, '\\u003C$1')` prevents script injection in JSON

### Content-Security-Policy

Admin tools that load external resources (e.g., from Enonic Market) should set CSP headers in the controller response:

```js
return {
    contentType: 'text/html',
    body: mustache.render(view, params),
    headers: {
        'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self' https://market.enonic.com"
    }
};
```

Adjust the `connect-src` directive to whitelist only the external domains your app actually contacts.

## Widget Controllers

Widgets are smaller UI components for the admin panel. Located in `admin/widgets/<name>/`.

### Descriptor (`admin/widgets/stats/stats.xml`)

```xml
<widget xmlns="urn:enonic:xp:model:1.0">
  <display-name>Statistics</display-name>
  <description>Show content statistics</description>
  <interfaces>
    <interface>admin.dashboard</interface>
  </interfaces>
  <config>
    <property name="width" value="small"/>
    <property name="height" value="small"/>
  </config>
</widget>
```

**Interfaces:**
- `admin.dashboard` -- shown on the admin dashboard

### Controller (`admin/widgets/stats/stats.js`)

```js
var mustache = require('/lib/mustache');
var contentLib = require('/lib/xp/content');
var portal = require('/lib/xp/portal');

exports.get = function(req) {
    var view = resolve('./stats.html');
    var params = {
        totalContent: contentLib.query({ count: 0 }).total,
        stylesUrl: portal.assetUrl({ path: 'styles/widgets/stats.css' })
    };

    return {
        contentType: 'text/html',
        body: mustache.render(view, params)
    };
};
```

## Error Handler

Handles HTTP errors for the application. Located in `error/error.js`.

### Controller (`error/error.js`)

```js
var thymeleaf = require('/lib/thymeleaf');

exports.handleError = function(err) {
    if (err.status === 404) {
        return {
            contentType: 'text/html',
            body: thymeleaf.render(resolve('404.html'), {
                message: 'Page not found'
            })
        };
    }

    // Return null to use default error handling
    return null;
};

// Alternative: handle specific status codes
exports.handle404 = function(err) {
    return {
        contentType: 'text/html',
        body: '<h1>Not Found</h1>'
    };
};
```

Error object:
```ts
interface Error {
    status: number;       // HTTP status code
    message: string;      // Error message
    exception: object;    // Java exception (if any)
    request: Request;     // Original request
}
```

## Webapp Controller

Entry point for standalone web applications (not site-based). Located in `webapp/webapp.js`.

### Controller (`webapp/webapp.js`)

```js
var mustache = require('/lib/mustache');
var portal = require('/lib/xp/portal');

exports.get = function(req) {
    var view = resolve('./app.html');
    var params = {
        assetsUri: portal.assetUrl({ path: '' }),
        appName: 'My Web App'
    };

    return {
        contentType: 'text/html',
        body: mustache.render(view, params)
    };
};
```

URL pattern: `<host>/webapp/<app-name>/`.

For routing, use the router library with `exports.all` to handle all HTTP methods:

```js
var router = require('/lib/router')();

router.get('/', function(req) {
    return renderIndex(req);
});

router.get('/api/data', function(req) {
    return getApiData(req);
});

router.post('/api/data', function(req) {
    return postApiData(req);
});

exports.all = function(req) {
    return router.dispatch(req);
};
```

## Response Processors

Modify the response after rendering. Located in `site/processors/<name>.js`.

### Controller (`site/processors/seo.js`)

```js
var portal = require('/lib/xp/portal');

exports.responseProcessor = function(req, res) {
    var content = portal.getContent();

    // Add meta tags to head
    var metaTags = '<meta name="description" content="' + (content.data.seoDescription || '') + '"/>';

    if (!res.pageContributions) {
        res.pageContributions = {};
    }
    if (!res.pageContributions.headEnd) {
        res.pageContributions.headEnd = [];
    }
    res.pageContributions.headEnd.push(metaTags);

    return res;
};
```

## WebSocket Controllers

Any controller can handle WebSocket connections:

```js
var websocketLib = require('/lib/xp/websocket');

exports.get = function(req) {
    if (!req.webSocket) {
        return { status: 400, body: 'WebSocket required' };
    }

    return {
        webSocket: {
            data: { userId: 'user-123' },
            subProtocols: ['json']
        }
    };
};

exports.webSocketEvent = function(event) {
    switch (event.type) {
        case 'open':
            websocketLib.addToGroup('chat', event.session.id);
            break;
        case 'message':
            websocketLib.sendToGroup('chat', event.message);
            break;
        case 'close':
            websocketLib.removeFromGroup('chat', event.session.id);
            break;
    }
};
```

## DELETE Handler (Reserved Word)

In JS, `delete` is a reserved word. Use this pattern:

```js
function _delete(req) {
    var id = JSON.parse(req.body).id;
    // ... delete logic
    return { status: 200, body: { success: true } };
}
exports.delete = _delete;
```

In TS:

```ts
export { _delete as delete };

function _delete(req: XP.Request): XP.Response {
    const { id } = JSON.parse(req.body);
    // ... delete logic
    return { status: 200, body: { success: true } };
}
```
