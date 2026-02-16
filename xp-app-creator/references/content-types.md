# Content Types, Mixins, X-Data

## Content Types

Content types define the schema for content items. Located in `site/content-types/<name>/<name>.xml`.

### Full XML Structure

```xml
<content-type>
  <display-name>Article</display-name>
  <display-name i18n="article.displayName">Article</display-name>  <!-- i18n variant -->
  <description>A news article with body text and metadata</description>
  <super-type>base:structured</super-type>
  <is-abstract>false</is-abstract>
  <is-final>false</is-final>
  <allow-child-content>true</allow-child-content>
  <form>
    <!-- inputs, item-sets, option-sets, field-sets, inline mixins -->
  </form>
</content-type>
```

### Key Elements

| Element | Default | Description |
|---------|---------|-------------|
| `<display-name>` | required | Name shown in Content Studio |
| `<description>` | -- | Description shown in content type selector |
| `<super-type>` | -- | Parent type to inherit from |
| `<is-abstract>` | `false` | Cannot create instances directly |
| `<is-final>` | `false` | Cannot be extended by other types |
| `<allow-child-content>` | `true` | Whether child content items are allowed |
| `<form>` | required | Form definition (can be empty: `<form/>`) |

### Built-in Super Types

| Super type | Description |
|-----------|-------------|
| `base:structured` | Standard content with custom form. **Most common choice.** |
| `base:unstructured` | No predefined form, any data accepted |
| `base:folder` | Container for organizing content |
| `base:shortcut` | Redirect to another content |
| `base:media` | Base for media types |

### Content Type with All Features

```xml
<content-type>
  <display-name i18n="landing-page.displayName">Landing Page</display-name>
  <description i18n="landing-page.description">Marketing landing page</description>
  <super-type>base:structured</super-type>
  <is-final>false</is-final>
  <allow-child-content>false</allow-child-content>
  <form>
    <input name="title" type="TextLine">
      <label i18n="landing-page.title.label">Title</label>
      <occurrences minimum="1" maximum="1"/>
    </input>

    <input name="heroImage" type="ImageSelector">
      <label>Hero Image</label>
      <occurrences minimum="0" maximum="1"/>
    </input>

    <input name="body" type="HtmlArea">
      <label>Body</label>
      <occurrences minimum="0" maximum="1"/>
    </input>

    <inline mixin="seo-metadata"/>

    <item-set name="features">
      <label>Features</label>
      <occurrences minimum="0" maximum="0"/>
      <items>
        <input name="icon" type="ImageSelector">
          <label>Icon</label>
        </input>
        <input name="heading" type="TextLine">
          <label>Heading</label>
          <occurrences minimum="1" maximum="1"/>
        </input>
        <input name="description" type="TextArea">
          <label>Description</label>
        </input>
      </items>
    </item-set>
  </form>
</content-type>
```

### Icons

Place an SVG icon next to the XML descriptor:

```
content-types/article/
├── article.xml
└── article.svg      # Shown in Content Studio
```

Or reference a built-in icon within the XML (not recommended -- SVG file is preferred).

## Mixins

Mixins are reusable form fragments that can be inlined into any content type, page, part, or layout form. Located in `site/mixins/<name>/<name>.xml`.

### XML Structure

```xml
<mixin>
  <display-name>SEO Metadata</display-name>
  <description>Common SEO fields</description>
  <form>
    <input name="seoTitle" type="TextLine">
      <label>SEO Title</label>
      <help-text>Override the page title for search engines</help-text>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="seoDescription" type="TextArea">
      <label>Meta Description</label>
      <help-text>Shown in search engine results (max 160 chars)</help-text>
      <occurrences minimum="0" maximum="1"/>
      <config>
        <max-length>160</max-length>
      </config>
    </input>
    <input name="seoImage" type="ImageSelector">
      <label>Social Share Image</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="noIndex" type="Checkbox">
      <label>Hide from search engines</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
  </form>
</mixin>
```

### Using Mixins

Inline a mixin into any form:

```xml
<content-type>
  <display-name>Article</display-name>
  <super-type>base:structured</super-type>
  <form>
    <input name="title" type="TextLine">
      <label>Title</label>
      <occurrences minimum="1" maximum="1"/>
    </input>
    <inline mixin="seo-metadata"/>
  </form>
</content-type>
```

The mixin's fields are inserted directly into the form at the `<inline>` position. The mixin name must match the directory name under `site/mixins/`.

### Accessing Mixin Fields

Mixin fields appear as top-level properties in the content data -- they are not nested:

```js
var content = portal.getContent();
// Mixin fields are directly on content.data
var seoTitle = content.data.seoTitle;
var seoDescription = content.data.seoDescription;
```

## X-Data (Extra Data)

X-Data adds extra fields to content types without modifying their schemas. Useful for cross-cutting concerns. Located in `site/x-data/<name>/<name>.xml`.

### XML Structure

```xml
<x-data>
  <display-name>Analytics</display-name>
  <description>Analytics tracking fields</description>
  <form>
    <input name="trackingId" type="TextLine">
      <label>Tracking ID</label>
      <occurrences minimum="0" maximum="1"/>
    </input>
    <input name="enableTracking" type="Checkbox">
      <label>Enable Tracking</label>
      <default>checked</default>
    </input>
  </form>
</x-data>
```

### Key Differences from Mixins

| Aspect | Mixin | X-Data |
|--------|-------|--------|
| Inclusion | Explicit `<inline>` in each content type | Activated in `site.xml` for all/filtered types |
| Data location | Top-level in `content.data` | Nested in `content.x.<app>.<name>` |
| Scope | Per content type | Cross-cutting (can apply to all types) |
| Modification | Requires editing each content type | Centralized in site.xml |

### Activating X-Data

In `site.xml`:

```xml
<site>
  <x-data name="analytics"/>
</site>
```

With content type filtering:

```xml
<site>
  <x-data name="analytics" allowContentTypes="article|blog-post"/>
  <x-data name="seo" allowContentTypes="*"/>
</site>
```

### Accessing X-Data in Controllers

X-Data values live under `content.x.<applicationKey>.<xdataName>`:

```js
var content = portal.getContent();
// X-Data is namespaced under the app key
var trackingId = content.x['com.example.myapp']['analytics'].trackingId;
// Or using app.name
var xdata = content.x[app.name]['analytics'];
```

```ts
const content = getContent();
const xdata = content.x?.[app.name]?.['analytics'];
const trackingId = xdata?.trackingId;
```

## Content Type References

### Reference Format

Content types are referenced as `<app-key>:<type-name>`:

```
com.example.myapp:article          # App-specific type
${app}:article                     # Dynamic app reference (in XML configs)
```

### Built-in Base Types

```
base:structured
base:unstructured
base:folder
base:shortcut
base:media
```

### Built-in Media Types

```
media:text, media:data, media:audio, media:video,
media:image, media:vector, media:archive,
media:document, media:spreadsheet, media:presentation,
media:code, media:executable, media:unknown
```

### Built-in Portal Types

```
portal:site
portal:page-template
portal:template-folder
portal:fragment
```

### Glob Patterns

Used in `allowContentTypes`, `ContentSelector`, and x-data filtering:

```
*                          # All types in current app
${app}:*                   # Same as above
article                    # Short form (current app implied)
com.other.app:*            # All types from another app
article|blog-post          # Multiple types (pipe-separated)
base:folder                # Built-in type
```
