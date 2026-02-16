---
name: xp-app-creator
description: >
  Enonic XP application development guide. Covers project setup (vanilla JS and
  TypeScript), component creation (pages, parts, layouts), content type schemas
  (content types, mixins, x-data), all 19 input types, controller patterns
  (JS and TS), site configuration, and build system (Gradle, tsup, webpack).
  Use when creating a new XP app, adding components or content types to an
  existing app, writing controllers, or configuring the build pipeline.
license: MIT
compatibility: Claude Code, Codex
allowed-tools: Bash(mkdir:*) Read Write Edit
metadata:
  author: enonic
  xp-version: "7.16"
---

## Critical Rules

1. **XML namespace** -- Descriptors for `<tool>`, `<widget>`, `<api>`, `<task>`, and `<service>` use `xmlns="urn:enonic:xp:model:1.0"`. Component descriptors (`<page>`, `<part>`, `<layout>`) and schema files (`<content-type>`, `<mixin>`, `<x-data>`, `<site>`, `<application>`) do NOT use a namespace.
2. **File naming** -- Component directory name must match descriptor filename: `parts/my-part/my-part.xml`. Content types: `content-types/article/article.xml`.
3. **Controller resolution** -- XP looks for `<name>.js` next to `<name>.xml`. In TS apps, tsup/webpack compiles `<name>.ts` to `<name>.js` in `build/resources/main/`.
4. **Form field names** -- Must be unique within a form. Use `name` attribute on `<input>`, not `id`.
5. **Occurrences defaults** -- `minimum="0" maximum="1"` if omitted. Use `maximum="0"` for unlimited.
6. **Content type naming** -- Full name is `${app}:type-name` where `${app}` resolves to the application key (e.g. `com.example.myapp`).
7. **App types** -- Three patterns: **Site apps** use `site/` directory (pages, parts, content-types). **Webapps** use `webapp/webapp.js` as entry point. **Admin tools** use `admin/tools/` only (no `site/`, no `webapp/`).
8. **processResources exclusion** -- TS apps must exclude source files from JAR: `.ts`, `.tsx`, `.json` (tsconfig files). Only compiled `.js` should be in the JAR.

## Initialization

**With CLI** (preferred): Use the `enonic-cli` skill. Run `enonic project create -r starter-vanilla` or `enonic project create -r starter-ts`.

**Without CLI**: See `references/build-system.md` for manual setup of build.gradle, gradle.properties, and settings.gradle.

**Key files to verify after init:**
- `gradle.properties` -- `appName`, `xpVersion`, `group` set correctly
- `src/main/resources/application.xml` -- exists with description
- `src/main/resources/site/site.xml` -- exists if building a site app (delete for webapp-only)
- `.enonic` -- links project to sandbox (created by CLI)

## Quick Reference: Creating Components

| Task | Files to create | Reference |
|------|----------------|-----------|
| Page | `site/pages/<name>/<name>.xml` + `.js`/`.ts` + `.html` | `references/components.md` |
| Part | `site/parts/<name>/<name>.xml` + `.js`/`.ts` + `.html` | `references/components.md` |
| Layout | `site/layouts/<name>/<name>.xml` + `.js`/`.ts` + `.html` | `references/components.md` |
| Content type | `site/content-types/<name>/<name>.xml` | `references/content-types.md` |
| Mixin | `site/mixins/<name>/<name>.xml` | `references/content-types.md` |
| X-Data | `site/x-data/<name>/<name>.xml` | `references/content-types.md` |
| Service | `services/<name>/<name>.xml` + `.js`/`.ts` | `references/controllers.md` |
| API | `apis/<name>/<name>.xml` + `.js`/`.ts` | `references/controllers.md` |
| Task | `tasks/<name>/<name>.xml` + `.js`/`.ts` | `references/controllers.md` |
| Admin tool | `admin/tools/<name>/<name>.xml` + `.js`/`.ts` + `.html` | `references/controllers.md` |
| Widget | `admin/widgets/<name>/<name>.xml` + `.js`/`.ts` + `.html` | `references/controllers.md` |
| Error handler | `error/error.js`/`.ts` | `references/controllers.md` |
| Response processor | `site/processors/<name>.js`/`.ts` | `references/controllers.md` |
| Webapp | `webapp/webapp.js`/`.ts` | `references/controllers.md` |

### Minimal Part Example

**XML** (`site/parts/hello/hello.xml`):
```xml
<part>
  <display-name>Hello</display-name>
  <description>A simple greeting part</description>
  <form>
    <input name="greeting" type="TextLine">
      <label>Greeting</label>
      <occurrences minimum="1" maximum="1"/>
    </input>
  </form>
</part>
```

**JS controller** (`site/parts/hello/hello.js`):
```js
var portal = require('/lib/xp/portal');
var thymeleaf = require('/lib/thymeleaf');

exports.get = function(req) {
    var component = portal.getComponent();
    var model = {
        greeting: component.config.greeting || 'Hello, World!'
    };
    return {
        body: thymeleaf.render(resolve('hello.html'), model)
    };
};
```

**TS controller** (`site/parts/hello/hello.ts`):
```ts
import { getComponent } from '/lib/xp/portal';
import { render } from '/lib/thymeleaf';

export function get(req: XP.Request): XP.Response {
    const component = getComponent<{ greeting?: string }>();
    const model = {
        greeting: component.config.greeting || 'Hello, World!'
    };
    return {
        body: render(resolve('hello.html'), model)
    };
}
```

**View** (`site/parts/hello/hello.html`):
```html
<div data-th-text="${greeting}">Placeholder</div>
```

### Minimal Content Type Example

**XML** (`site/content-types/article/article.xml`):
```xml
<content-type>
  <display-name>Article</display-name>
  <description>News article</description>
  <super-type>base:structured</super-type>
  <form>
    <input name="title" type="TextLine">
      <label>Title</label>
      <occurrences minimum="1" maximum="1"/>
    </input>
    <input name="body" type="HtmlArea">
      <label>Body</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="image" type="ImageSelector">
      <label>Featured Image</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
  </form>
</content-type>
```

## Input Types Quick Lookup

| Type | Description | Key config |
|------|-------------|------------|
| `TextLine` | Single-line text | `regexp`, `max-length` |
| `TextArea` | Multi-line text | `max-length` |
| `HtmlArea` | Rich text editor | `allowedContentTypes` (image/media filter) |
| `Checkbox` | Boolean toggle | `default` ("checked") |
| `ComboBox` | Dropdown select | `<option>` children, `max` |
| `RadioButton` | Single choice | `<option>` children |
| `Tag` | Tag input | -- |
| `Date` | Date picker | `default`, `timezone` |
| `DateTime` | Date + time | `default`, `timezone` |
| `Time` | Time picker | `default` |
| `Long` | Integer | `default` |
| `Double` | Decimal | `default` |
| `GeoPoint` | Lat/lon | -- |
| `ContentSelector` | Content reference | `allowContentType`, `allowPath` |
| `ImageSelector` | Image reference | `allowPath` |
| `MediaSelector` | Media reference | `allowContentType`, `allowPath` |
| `AttachmentUploader` | File upload | -- |
| `CustomSelector` | Custom endpoint | `service` |
| `ContentTypeFilter` | Content type filter | -- |

All types support: `name`, `label`, `help-text`, `occurrences`, `default`.

See `references/input-types.md` for full XML examples and config options.

## Form Structures Quick Reference

**ItemSet** -- repeatable group of fields:
```xml
<item-set name="links">
  <label>Links</label>
  <occurrences minimum="0" maximum="0"/>
  <items>
    <input name="url" type="TextLine"><label>URL</label></input>
    <input name="text" type="TextLine"><label>Text</label></input>
  </items>
</item-set>
```

**OptionSet** -- choose between alternative field groups:
```xml
<option-set name="media">
  <label>Media</label>
  <options minimum="1" maximum="1">
    <option name="image">
      <label>Image</label>
      <items>
        <input name="image" type="ImageSelector"><label>Image</label></input>
      </items>
    </option>
    <option name="video">
      <label>Video</label>
      <items>
        <input name="url" type="TextLine"><label>Video URL</label></input>
      </items>
    </option>
  </options>
</option-set>
```

**FieldSet** -- visual grouping (no data structure):
```xml
<field-set name="metadata">
  <label>Metadata</label>
  <items>
    <input name="tags" type="Tag"><label>Tags</label></input>
  </items>
</field-set>
```

**Inline mixin**:
```xml
<inline mixin="my-mixin"/>
```

## Common API Patterns

**Portal lib** (`/lib/xp/portal`):
- `getComponent()` -- current page/part/layout config
- `getContent()` -- current content in context
- `getSiteConfig()` -- site.xml config values
- `assetUrl({ path })` -- URL to static asset
- `serviceUrl({ service })` -- URL to service controller
- `apiUrl({ api })` -- URL to API endpoint **(XP 8+)**
- `pageUrl({ path })` -- URL to content path
- `imageUrl({ id, scale })` -- URL to image

**Asset lib** (`/lib/enonic/asset`) -- for admin tools without portal context:
- `assetUrl({ path })` -- URL to static asset (use instead of `portal.assetUrl` in admin tools)

**Content lib** (`/lib/xp/content`):
- `get({ key })` -- get content by ID or path
- `query({ query, contentTypes, count, start })` -- query content
- `create({ name, parentPath, contentType, data })` -- create content
- `modify({ key, editor })` -- modify content

**Thymeleaf** (`/lib/thymeleaf`):
- `render(view, model)` -- render template with model
- Use `resolve('template.html')` to get view reference

**Global objects** (available in all controllers):
- `app.name` -- application key (e.g. `com.example.myapp`)
- `app.version` -- application version
- `app.config` -- values from `<appName>.cfg` in XP home config directory (e.g. `com.example.myapp.cfg`)
- `log.info()`, `log.error()`, `log.debug()`, `log.warning()`
- `__` (double underscore) -- Java interop (`__.newBean()`, `__.toNativeObject()`)
- `resolve(path)` -- resolve relative resource path

**Controller response format**:
```js
return {
    status: 200,                          // HTTP status (default 200)
    contentType: 'text/html',             // MIME type
    body: content,                        // string, object (auto-JSON), or stream
    headers: { 'Cache-Control': '...' },  // optional
    cookies: {},                          // optional
    pageContributions: {                  // optional (pages/parts/layouts only)
        headBegin: [],
        headEnd: [],
        bodyBegin: [],
        bodyEnd: []
    }
};
```

## Reference Files

| File | Load when... |
|------|-------------|
| `references/project-structure.md` | Setting up a new project or understanding directory layout |
| `references/components.md` | Creating pages, parts, or layouts with controllers and views |
| `references/content-types.md` | Creating content types, mixins, or x-data schemas |
| `references/input-types.md` | Need full XML syntax for specific input types or form structures |
| `references/controllers.md` | Writing controllers for services, tasks, admin tools, widgets, error handlers |
| `references/site-config.md` | Configuring site.xml, content mappings, or x-data activation |
| `references/build-system.md` | Setting up or modifying Gradle, tsup, or webpack build pipeline |
