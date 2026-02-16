# Project Structure

## Standard Directory Tree

```
my-app/
├── .enonic                          # Sandbox link (created by CLI)
├── build.gradle                     # Build configuration
├── gradle.properties                # App metadata and versions
├── settings.gradle                  # Project name setting
├── gradlew / gradlew.bat            # Gradle wrapper
├── gradle/                          # Gradle wrapper files
├── package.json                     # [TS only] npm dependencies and scripts
├── tsconfig.json                    # [TS only] Root TS config (build scripts)
├── tsup.config.ts                   # [TS only] tsup bundler configuration
├── tsup/                            # [TS only] Build/check helper scripts
│   ├── build.js                     #   Build runner
│   ├── check.js                     #   Type-check runner
│   ├── server.ts                    #   Server bundle config
│   ├── client.ts                    #   Client bundle config
│   ├── constants.ts                 #   Path constants
│   ├── dict.ts                      #   Utility
│   └── index.d.ts                   #   Options type
└── src/main/
    ├── java/                        # Optional Java code (OSGi services)
    └── resources/
        ├── application.xml          # App descriptor
        ├── application.svg          # App icon
        ├── main.js / main.ts        # App lifecycle (optional)
        ├── tsconfig.json            # [TS only] Server-side TS config
        │
        ├── site/                    # Site components (for site apps)
        │   ├── site.xml             # Site configuration form
        │   ├── content-types/       # Content type schemas
        │   │   └── <name>/
        │   │       ├── <name>.xml
        │   │       └── <name>.svg   # Optional icon
        │   ├── pages/
        │   │   └── <name>/
        │   │       ├── <name>.xml   # Descriptor
        │   │       ├── <name>.js    # Controller
        │   │       └── <name>.html  # View template
        │   ├── parts/
        │   │   └── <name>/
        │   │       ├── <name>.xml
        │   │       ├── <name>.js
        │   │       └── <name>.html
        │   ├── layouts/
        │   │   └── <name>/
        │   │       ├── <name>.xml
        │   │       ├── <name>.js
        │   │       └── <name>.html
        │   ├── mixins/
        │   │   └── <name>/
        │   │       └── <name>.xml
        │   ├── x-data/
        │   │   └── <name>/
        │   │       └── <name>.xml
        │   └── processors/          # Response processors
        │       └── <name>.js
        │
        ├── services/                # HTTP service endpoints
        │   └── <name>/
        │       ├── <name>.xml       # Access control (optional)
        │       └── <name>.js
        │
        ├── apis/                    # API endpoints (newer convention)
        │   └── <name>/
        │       ├── <name>.xml       # Access control
        │       └── <name>.js
        │
        ├── tasks/                   # Background tasks
        │   └── <name>/
        │       ├── <name>.xml       # Task descriptor (form for params)
        │       └── <name>.js
        │
        ├── admin/
        │   ├── tools/               # Admin tool UIs
        │   │   └── <name>/
        │   │       ├── <name>.xml
        │   │       ├── <name>.js
        │   │       └── <name>.html
        │   └── widgets/             # Admin widgets
        │       └── <name>/
        │           ├── <name>.xml
        │           ├── <name>.js
        │           └── <name>.html
        │
        ├── webapp/                  # Webapp entry point
        │   └── webapp.js
        │
        ├── error/                   # Error handlers
        │   └── error.js
        │
        ├── assets/                  # Static files (CSS, client JS, images)
        │   ├── tsconfig.json        # [TS only] Client-side TS config
        │   ├── js/
        │   ├── styles/
        │   └── images/
        │
        ├── i18n/                    # Localization
        │   ├── phrases.properties   # Default locale
        │   └── phrases_no.properties
        │
        └── lib/                     # App-specific server-side libraries
            └── <app-lib>.js
```

## Key Files Explained

### gradle.properties

```properties
group = com.example                # Maven group
projectName = my-app               # Project directory name
version = 1.0.0-SNAPSHOT           # App version
appDisplayName = My Application    # Human-readable name
appName = com.example.my-app       # Application key (unique identifier)
vendorName = Acme Inc              # Vendor
vendorUrl = https://example.com    # Vendor URL
xpVersion = 7.16.1                 # Required XP version
```

**Application key** (`appName`) is the most important value. It determines:
- Content type prefixes: `com.example.my-app:article`
- Config file name: `com.example.my-app.cfg`
- JAR artifact name

### application.xml

```xml
<application>
  <description>My Application</description>
</application>
```

Minimal required file. Description shown in XP admin.

### site.xml

```xml
<site>
  <!-- Empty: no site config form -->
</site>
```

Required for site apps. Delete this file for standalone webapps. See `site-config.md` for adding configuration forms and mappings.

### .enonic

Created by `enonic project create`. Links project to a sandbox:
```json
{
  "sandbox": "my-sandbox"
}
```

### main.js / main.ts

Optional app lifecycle entry point. Runs when app starts/stops:

```js
var clusterLib = require('/lib/xp/cluster');

log.info('App started: ' + app.name);

// Run initialization only on master node
if (clusterLib.isMaster()) {
    // Create repos, initialize data, schedule tasks
}

__.disposer(function() {
    log.info('App stopped: ' + app.name);
});
```

### i18n/phrases.properties

```properties
# Key-value pairs for localization
my-part.greeting=Hello
my-content-type.displayName=Article
my-content-type.description=A news article
my-content-type.title.label=Title
```

Used in XML with `i18n="key"` attribute:
```xml
<display-name i18n="my-content-type.displayName">Article</display-name>
```

Used in controllers with `/lib/xp/i18n`:
```js
var i18n = require('/lib/xp/i18n');
var text = i18n.localize({ key: 'my-part.greeting' });
```

## Naming Conventions

- **Component directories**: lowercase, hyphen-separated (`my-page`, `hero-banner`)
- **Content type directories**: lowercase, hyphen-separated (`landing-page`, `blog-post`)
- **Application key**: reverse domain, dots and hyphens (`com.example.my-app`)
- **File names**: must match directory name (`my-part/my-part.xml`)
- **i18n keys**: dot-separated hierarchy (`component.field.label`)
