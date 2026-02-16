# Site Configuration

## site.xml

Located at `src/main/resources/site/site.xml`. Required for site-based applications. Delete for standalone webapps.

### Empty Site (No Config)

```xml
<site>
</site>
```

### Site with Configuration Form

```xml
<site>
  <form>
    <input name="analyticsId" type="TextLine">
      <label>Google Analytics ID</label>
      <help-text>Enter your GA tracking ID (e.g. UA-XXXXX-Y)</help-text>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="footerText" type="TextArea">
      <label>Footer Text</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="logo" type="ImageSelector">
      <label>Site Logo</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
  </form>
</site>
```

### Accessing Site Config

In any page/part/layout controller:

```js
var portal = require('/lib/xp/portal');

exports.get = function(req) {
    var siteConfig = portal.getSiteConfig();
    var analyticsId = siteConfig.analyticsId;
    var footerText = siteConfig.footerText;
    // ...
};
```

```ts
import { getSiteConfig } from '/lib/xp/portal';

interface SiteConfig {
    analyticsId?: string;
    footerText?: string;
    logo?: string;
}

export function get(req: XP.Request): XP.Response {
    const siteConfig = getSiteConfig<SiteConfig>();
    const analyticsId = siteConfig.analyticsId;
    // ...
}
```

## Content Mappings

Map controllers or filters to content paths/types without page components. Defined in `site.xml`.

### Controller Mapping

Route specific content to a controller:

```xml
<site>
  <mappings>
    <mapping controller="/site/pages/article/article.js">
      <match>type:'${app}:article'</match>
    </mapping>
    <mapping controller="/site/pages/default/default.js">
      <pattern>/.*</pattern>
    </mapping>
  </mappings>
</site>
```

### Filter Mapping

Apply filters to content:

```xml
<site>
  <mappings>
    <mapping filter="/site/filters/auth.js">
      <pattern>/members/.*</pattern>
    </mapping>
  </mappings>
</site>
```

### Service Mapping

Map a service to content paths:

```xml
<site>
  <mappings>
    <mapping service="api-service">
      <pattern>/api/.*</pattern>
    </mapping>
  </mappings>
</site>
```

### Match vs Pattern

| Attribute | Description | Example |
|-----------|-------------|---------|
| `<match>` | Content query expression | `type:'${app}:article'` |
| `<pattern>` | URL path regex | `/blog/.*` |

**Match expressions:**
- `type:'${app}:article'` -- content type
- `_path:'/mysite/blog/.*'` -- content path pattern

### Mapping Order

Mappings are evaluated top-to-bottom. First match wins:

```xml
<mappings>
  <!-- Specific matches first -->
  <mapping controller="/site/pages/article.js">
    <match>type:'${app}:article'</match>
  </mapping>
  <!-- General fallback last -->
  <mapping controller="/site/pages/default.js">
    <pattern>/.*</pattern>
  </mapping>
</mappings>
```

## X-Data Activation

Activate x-data schemas for content types. Defined in `site.xml`.

### Activate for All Content Types

```xml
<site>
  <x-data name="seo"/>
</site>
```

### Activate for Specific Types

```xml
<site>
  <x-data name="seo" allowContentTypes="article|blog-post|landing-page"/>
  <x-data name="analytics" allowContentTypes="*"/>
</site>
```

### Pattern Matching

```
*                    # All content types in current app
article              # Specific type (short form)
${app}:article       # Specific type (full form)
article|blog-post    # Multiple types (pipe-separated)
base:folder          # Built-in type
```

## Full site.xml Example

```xml
<site>
  <form>
    <input name="analyticsId" type="TextLine">
      <label>Analytics ID</label>
    </input>
    <input name="logo" type="ImageSelector">
      <label>Logo</label>
    </input>
  </form>

  <x-data name="seo" allowContentTypes="article|landing-page"/>
  <x-data name="open-graph" allowContentTypes="*"/>

  <mappings>
    <mapping controller="/site/pages/article/article.js">
      <match>type:'${app}:article'</match>
    </mapping>
    <mapping filter="/site/filters/cache.js">
      <pattern>/.*</pattern>
    </mapping>
  </mappings>
</site>
```

## Response Filters

Filter controllers intercept and modify responses:

```js
exports.responseFilter = function(req, res) {
    // Modify response before sending
    res.headers = res.headers || {};
    res.headers['X-Custom-Header'] = 'value';
    return res;
};
```

Filters are mapped in `site.xml` using `<mapping filter="...">`.
