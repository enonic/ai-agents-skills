# Input Types

## Common Attributes

All input types share these attributes:

```xml
<input name="fieldName" type="TypeName">
  <label>Field Label</label>                        <!-- Required -->
  <label i18n="key">Field Label</label>             <!-- i18n variant -->
  <help-text>Shown below the field</help-text>      <!-- Optional -->
  <occurrences minimum="0" maximum="1"/>            <!-- Optional, default 0..1 -->
  <default>default value</default>                  <!-- Optional -->
  <config>
    <!-- Type-specific config -->
  </config>
</input>
```

**Occurrences:**
- `minimum="0" maximum="1"` -- optional, single value (default)
- `minimum="1" maximum="1"` -- required, single value
- `minimum="0" maximum="0"` -- optional, unlimited values
- `minimum="1" maximum="0"` -- at least one, unlimited values

## Text Inputs

### TextLine

Single-line text input.

```xml
<input name="title" type="TextLine">
  <label>Title</label>
  <occurrences minimum="1" maximum="1"/>
  <default>Untitled</default>
  <config>
    <max-length>100</max-length>
    <regexp>[A-Za-z0-9\s]+</regexp>
  </config>
</input>
```

Config: `max-length`, `regexp`.

### TextArea

Multi-line plain text.

```xml
<input name="description" type="TextArea">
  <label>Description</label>
  <config>
    <max-length>500</max-length>
  </config>
</input>
```

Config: `max-length`.

### HtmlArea

Rich text editor (CKEditor-based).

```xml
<input name="body" type="HtmlArea">
  <label>Body Content</label>
  <occurrences minimum="0" maximum="1"/>
  <config>
    <allowedContentTypes>image/*</allowedContentTypes>
  </config>
</input>
```

Config: `allowedContentTypes` (filter for images/media that can be inserted).

### Tag

Tag / keyword input.

```xml
<input name="tags" type="Tag">
  <label>Tags</label>
  <occurrences minimum="0" maximum="0"/>
</input>
```

No type-specific config.

## Numeric Inputs

### Long

Integer number.

```xml
<input name="count" type="Long">
  <label>Count</label>
  <default>0</default>
</input>
```

### Double

Decimal number.

```xml
<input name="price" type="Double">
  <label>Price</label>
  <default>0.0</default>
</input>
```

## Boolean

### Checkbox

Boolean toggle.

```xml
<input name="featured" type="Checkbox">
  <label>Featured</label>
  <default>checked</default>
</input>
```

Default value is `checked` (true) or omitted (false). Stored as boolean.

## Selection Inputs

### ComboBox

Dropdown select with predefined options.

```xml
<input name="category" type="ComboBox">
  <label>Category</label>
  <occurrences minimum="1" maximum="1"/>
  <config>
    <option value="news">News</option>
    <option value="blog">Blog Post</option>
    <option value="tutorial">Tutorial</option>
  </config>
</input>
```

For multi-select, set `occurrences maximum="0"`.

### RadioButton

Single choice from predefined options.

```xml
<input name="alignment" type="RadioButton">
  <label>Alignment</label>
  <config>
    <option value="left">Left</option>
    <option value="center">Center</option>
    <option value="right">Right</option>
  </config>
</input>
```

Always single value (no multi-select).

## Date and Time

### Date

Date picker (no time).

```xml
<input name="publishDate" type="Date">
  <label>Publish Date</label>
  <default>2024-01-01</default>
</input>
```

Format: `YYYY-MM-DD`. Config: `timezone`.

### DateTime

Date and time picker.

```xml
<input name="eventStart" type="DateTime">
  <label>Event Start</label>
  <config>
    <timezone>true</timezone>
  </config>
</input>
```

Format: `YYYY-MM-DDThh:mm`. Config: `timezone` (boolean -- show timezone selector).

### Time

Time picker (no date).

```xml
<input name="openingTime" type="Time">
  <label>Opening Time</label>
  <default>09:00</default>
</input>
```

Format: `hh:mm`.

## Content Reference Inputs

### ContentSelector

Select content items by reference.

```xml
<input name="relatedArticles" type="ContentSelector">
  <label>Related Articles</label>
  <occurrences minimum="0" maximum="3"/>
  <config>
    <allowContentType>article</allowContentType>
    <allowContentType>blog-post</allowContentType>
    <allowPath>${site}/articles/*</allowPath>
  </config>
</input>
```

Config:
- `allowContentType` -- filter by content type (multiple allowed)
- `allowPath` -- restrict to content tree paths (`${site}` = current site)

### ImageSelector

Select image content.

```xml
<input name="image" type="ImageSelector">
  <label>Image</label>
  <occurrences minimum="0" maximum="1"/>
  <config>
    <allowPath>${site}/*</allowPath>
  </config>
</input>
```

Config: `allowPath`.

### MediaSelector

Select any media content.

```xml
<input name="attachment" type="MediaSelector">
  <label>Attachment</label>
  <occurrences minimum="0" maximum="0"/>
  <config>
    <allowContentType>media:document</allowContentType>
    <allowContentType>media:spreadsheet</allowContentType>
    <allowPath>${site}/files/*</allowPath>
  </config>
</input>
```

Config: `allowContentType`, `allowPath`.

### AttachmentUploader

Direct file upload (attached to current content).

```xml
<input name="file" type="AttachmentUploader">
  <label>Upload File</label>
  <occurrences minimum="0" maximum="1"/>
</input>
```

No type-specific config.

## Special Inputs

### CustomSelector

Custom selection endpoint (backed by a service).

```xml
<input name="externalItem" type="CustomSelector">
  <label>External Item</label>
  <config>
    <service>custom-selector-service</service>
  </config>
</input>
```

Config: `service` -- name of the service that provides options.

### ContentTypeFilter

Filter by content type. Used in site configuration to restrict content types.

```xml
<input name="allowedTypes" type="ContentTypeFilter">
  <label>Allowed Content Types</label>
  <occurrences minimum="0" maximum="0"/>
</input>
```

### GeoPoint

Geographic coordinates (latitude/longitude).

```xml
<input name="location" type="GeoPoint">
  <label>Location</label>
  <occurrences minimum="0" maximum="1"/>
</input>
```

Stored as `{ lat, lon }`.

## Form Structures

### ItemSet

Repeatable group of fields. Creates array of objects in content data.

```xml
<item-set name="links">
  <label>Links</label>
  <help-text>Add links to related resources</help-text>
  <occurrences minimum="0" maximum="0"/>
  <items>
    <input name="text" type="TextLine">
      <label>Link Text</label>
      <occurrences minimum="1" maximum="1"/>
    </input>
    <input name="url" type="TextLine">
      <label>URL</label>
      <occurrences minimum="1" maximum="1"/>
      <config>
        <regexp>https?://.*</regexp>
      </config>
    </input>
    <input name="openInNewTab" type="Checkbox">
      <label>Open in new tab</label>
    </input>
  </items>
</item-set>
```

Data structure:
```json
{
  "links": [
    { "text": "Example", "url": "https://example.com", "openInNewTab": true },
    { "text": "Docs", "url": "https://docs.example.com", "openInNewTab": false }
  ]
}
```

### OptionSet

Choose between alternative field groups. The editor picks one (or more) options.

```xml
<option-set name="media">
  <label>Media</label>
  <help-text>Choose the media type</help-text>
  <options minimum="1" maximum="1">
    <option name="image">
      <label>Image</label>
      <items>
        <input name="imageContent" type="ImageSelector">
          <label>Image</label>
          <occurrences minimum="1" maximum="1"/>
        </input>
        <input name="caption" type="TextLine">
          <label>Caption</label>
        </input>
      </items>
    </option>
    <option name="video">
      <label>Video</label>
      <items>
        <input name="videoUrl" type="TextLine">
          <label>Video URL</label>
          <occurrences minimum="1" maximum="1"/>
        </input>
        <input name="autoplay" type="Checkbox">
          <label>Autoplay</label>
        </input>
      </items>
    </option>
    <option name="embed">
      <label>HTML Embed</label>
      <items>
        <input name="embedCode" type="TextArea">
          <label>Embed Code</label>
          <occurrences minimum="1" maximum="1"/>
        </input>
      </items>
    </option>
  </options>
</option-set>
```

Data structure:
```json
{
  "media": {
    "_selected": "image",
    "image": {
      "imageContent": "content-id",
      "caption": "Photo by..."
    }
  }
}
```

`<options minimum="1" maximum="1">` -- exactly one option must be selected.
`<options minimum="0" maximum="0">` -- any number of options can be selected.

### FieldSet

Visual grouping only -- does not affect data structure.

```xml
<field-set name="metadata">
  <label>Metadata</label>
  <items>
    <input name="author" type="TextLine">
      <label>Author</label>
    </input>
    <input name="publishDate" type="Date">
      <label>Publish Date</label>
    </input>
  </items>
</field-set>
```

Fields inside a FieldSet are stored at the same level as fields outside it (no nesting).

### Inline Mixin

Include a mixin's fields at the current position:

```xml
<form>
  <input name="title" type="TextLine">
    <label>Title</label>
  </input>
  <inline mixin="seo-metadata"/>
  <input name="category" type="ComboBox">
    <label>Category</label>
    <config>
      <option value="news">News</option>
    </config>
  </input>
</form>
```
