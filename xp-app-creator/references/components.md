# Components: Pages, Parts, Layouts

All site components follow the same pattern: XML descriptor + JS/TS controller + HTML view template.

## Page Component

Pages are the top-level component assigned to content. They define regions where parts and layouts can be placed.

### XML Descriptor (`site/pages/main/main.xml`)

```xml
<page>
  <display-name>Main Page</display-name>
  <description>Default page template with a single region</description>
  <form>
    <input name="title" type="TextLine">
      <label>Page Title Override</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
  </form>
  <regions>
    <region name="main"/>
  </regions>
</page>
```

**Key elements:**
- `<display-name>` -- shown in Content Studio when selecting page controller
- `<form>` -- optional configuration form (fields accessible via `component.config`)
- `<regions>` -- named regions where editors can place parts and layouts

### JS Controller (`site/pages/main/main.js`)

```js
var portal = require('/lib/xp/portal');
var thymeleaf = require('/lib/thymeleaf');

exports.get = function(req) {
    var content = portal.getContent();
    var component = portal.getComponent();
    var site = portal.getSite();

    var model = {
        title: component.config.title || content.displayName,
        mainRegion: component.regions.main,
        sitePath: site._path
    };

    return {
        body: thymeleaf.render(resolve('main.html'), model)
    };
};
```

### TS Controller (`site/pages/main/main.ts`)

```ts
import { getContent, getComponent, getSite } from '/lib/xp/portal';
import { render } from '/lib/thymeleaf';

interface PageConfig {
    title?: string;
}

export function get(req: XP.Request): XP.Response {
    const content = getContent();
    const component = getComponent<PageConfig>();
    const site = getSite();

    const model = {
        title: component.config.title || content.displayName,
        mainRegion: component.regions.main,
        sitePath: site._path
    };

    return {
        body: render(resolve('main.html'), model)
    };
}
```

### Thymeleaf View (`site/pages/main/main.html`)

```html
<!DOCTYPE html>
<html>
<head>
    <title data-th-text="${title}">Page Title</title>
</head>
<body>
    <h1 data-th-text="${title}">Title</h1>
    <div data-th-attribute="data-portal-region=main">
        <div data-th-each="component : ${mainRegion.components}"
             data-th-remove="tag">
            <div data-portal-component="${component.path}"></div>
        </div>
    </div>
</body>
</html>
```

**Region rendering** is the critical pattern -- the `data-portal-component` attribute tells XP to render each component in the region.

### Page with Multiple Regions

```xml
<page>
  <display-name>Two Column</display-name>
  <form/>
  <regions>
    <region name="left"/>
    <region name="right"/>
  </regions>
</page>
```

View:
```html
<div class="row">
    <div class="col-6" data-th-attribute="data-portal-region=left">
        <div data-th-each="component : ${leftRegion.components}"
             data-th-remove="tag">
            <div data-portal-component="${component.path}"></div>
        </div>
    </div>
    <div class="col-6" data-th-attribute="data-portal-region=right">
        <div data-th-each="component : ${rightRegion.components}"
             data-th-remove="tag">
            <div data-portal-component="${component.path}"></div>
        </div>
    </div>
</div>
```

Controller passes both regions:
```js
var model = {
    leftRegion: component.regions.left,
    rightRegion: component.regions.right
};
```

## Part Component

Parts are reusable components placed inside page regions. They have a config form but no regions of their own.

### XML Descriptor (`site/parts/hero/hero.xml`)

```xml
<part>
  <display-name>Hero Banner</display-name>
  <description>Full-width banner with heading and CTA</description>
  <form>
    <input name="heading" type="TextLine">
      <label>Heading</label>
      <occurrences minimum="1" maximum="1"/>
    </input>
    <input name="subheading" type="TextArea">
      <label>Subheading</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="backgroundImage" type="ImageSelector">
      <label>Background Image</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="ctaText" type="TextLine">
      <label>Button Text</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="ctaUrl" type="TextLine">
      <label>Button URL</label>
      <occurrences minimum="0" maximum="1"/>
      <config>
        <regexp>https?://.*</regexp>
      </config>
    </input>
  </form>
</part>
```

### JS Controller (`site/parts/hero/hero.js`)

```js
var portal = require('/lib/xp/portal');
var thymeleaf = require('/lib/thymeleaf');

exports.get = function(req) {
    var component = portal.getComponent();
    var config = component.config;

    var model = {
        heading: config.heading,
        subheading: config.subheading,
        ctaText: config.ctaText,
        ctaUrl: config.ctaUrl
    };

    if (config.backgroundImage) {
        model.imageUrl = portal.imageUrl({
            id: config.backgroundImage,
            scale: 'width(1920)'
        });
    }

    return {
        body: thymeleaf.render(resolve('hero.html'), model)
    };
};
```

### TS Controller (`site/parts/hero/hero.ts`)

```ts
import { getComponent, imageUrl } from '/lib/xp/portal';
import { render } from '/lib/thymeleaf';

interface HeroConfig {
    heading: string;
    subheading?: string;
    backgroundImage?: string;
    ctaText?: string;
    ctaUrl?: string;
}

export function get(req: XP.Request): XP.Response {
    const component = getComponent<HeroConfig>();
    const config = component.config;

    const model: Record<string, unknown> = {
        heading: config.heading,
        subheading: config.subheading,
        ctaText: config.ctaText,
        ctaUrl: config.ctaUrl
    };

    if (config.backgroundImage) {
        model.imageUrl = imageUrl({
            id: config.backgroundImage,
            scale: 'width(1920)'
        });
    }

    return {
        body: render(resolve('hero.html'), model)
    };
}
```

### View (`site/parts/hero/hero.html`)

```html
<section class="hero" data-th-if="${heading}"
         data-th-style="${imageUrl} ? 'background-image: url(' + ${imageUrl} + ')'">
    <h1 data-th-text="${heading}">Heading</h1>
    <p data-th-if="${subheading}" data-th-text="${subheading}">Subheading</p>
    <a data-th-if="${ctaText}" data-th-href="${ctaUrl}" data-th-text="${ctaText}">CTA</a>
</section>
```

## Layout Component

Layouts are like parts but with regions, allowing nested component placement. They sit inside a page region and provide their own sub-regions.

### XML Descriptor (`site/layouts/two-column/two-column.xml`)

```xml
<layout>
  <display-name>Two Column Layout</display-name>
  <description>Split content into two columns</description>
  <form>
    <input name="leftWidth" type="ComboBox">
      <label>Left Column Width</label>
      <occurrences minimum="0" maximum="1"/>
      <config>
        <option value="4">1/3</option>
        <option value="6">1/2</option>
        <option value="8">2/3</option>
      </config>
    </input>
  </form>
  <regions>
    <region name="left"/>
    <region name="right"/>
  </regions>
</layout>
```

### JS Controller (`site/layouts/two-column/two-column.js`)

```js
var portal = require('/lib/xp/portal');
var thymeleaf = require('/lib/thymeleaf');

exports.get = function(req) {
    var component = portal.getComponent();
    var leftWidth = parseInt(component.config.leftWidth || '6', 10);

    var model = {
        leftRegion: component.regions.left,
        rightRegion: component.regions.right,
        leftWidth: leftWidth,
        rightWidth: 12 - leftWidth
    };

    return {
        body: thymeleaf.render(resolve('two-column.html'), model)
    };
};
```

### TS Controller (`site/layouts/two-column/two-column.ts`)

```ts
import { getComponent } from '/lib/xp/portal';
import { render } from '/lib/thymeleaf';

interface TwoColumnConfig {
    leftWidth?: string;
}

export function get(req: XP.Request): XP.Response {
    const component = getComponent<TwoColumnConfig>();
    const leftWidth = parseInt(component.config.leftWidth || '6', 10);

    const model = {
        leftRegion: component.regions.left,
        rightRegion: component.regions.right,
        leftWidth,
        rightWidth: 12 - leftWidth
    };

    return {
        body: render(resolve('two-column.html'), model)
    };
}
```

### View (`site/layouts/two-column/two-column.html`)

```html
<div class="row">
    <div data-th-classappend="'col-' + ${leftWidth}"
         data-th-attribute="data-portal-region=left">
        <div data-th-each="component : ${leftRegion.components}"
             data-th-remove="tag">
            <div data-portal-component="${component.path}"></div>
        </div>
    </div>
    <div data-th-classappend="'col-' + ${rightWidth}"
         data-th-attribute="data-portal-region=right">
        <div data-th-each="component : ${rightRegion.components}"
             data-th-remove="tag">
            <div data-portal-component="${component.path}"></div>
        </div>
    </div>
</div>
```

## Common Patterns

### getComponent() vs getContent()

- `portal.getComponent()` -- returns the current component's config and regions. Use in page, part, and layout controllers.
- `portal.getContent()` -- returns the content item being rendered. Use when you need the content's data fields.

### Page Contributions

Add CSS/JS to the page head or body from any component:

```js
return {
    body: thymeleaf.render(resolve('my-part.html'), model),
    pageContributions: {
        headEnd: [
            '<link rel="stylesheet" href="' + portal.assetUrl({ path: 'css/my-part.css' }) + '"/>'
        ],
        bodyEnd: [
            '<script src="' + portal.assetUrl({ path: 'js/my-part.js' }) + '"></script>'
        ]
    }
};
```

### Empty Form

If a component needs no configuration:

```xml
<part>
  <display-name>Footer</display-name>
  <form/>
</part>
```

### Mustache Alternative

Some apps use Mustache instead of Thymeleaf:

```js
var mustache = require('/lib/mustache');

exports.get = function(req) {
    var view = resolve('template.html');
    return {
        contentType: 'text/html',
        body: mustache.render(view, model)
    };
};
```

Mustache template syntax: `{{variable}}`, `{{#condition}}...{{/condition}}`, `{{> partial}}`.
