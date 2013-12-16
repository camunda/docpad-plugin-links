# Links plugin for DocPad 

<img src="https://travis-ci.org/camunda/docpad-plugin-links.png" data-bindattr-269="269" title="Build Status Images">

A markup agnostic [DocPad](http://docpad.org) plug-in for smooth linking in large project documentations.


## Overview

The plug-in hooks into DocPad's page generation process and replaces `ref:` prefixes with relative references to the specified file.
At the same time it stores the references and validates them against existing files in a project.


### Page `/index.html`

```html
Check out <a href="ref:/b/#my-heading">this section</a> on <a href="ref:/b/">the other page</a>.
Or try <a href="ref:/broken.html">a broken link</a>.
```


### Page `/b/index.html.md`

```markdown
## my heading
This page may **safely** be linked to.
```


### Console Output

```
~: docpad generate

...

[docpad-plugin-links] processing documents
[docpad-plugin-links] completed in 11708 ms
[docpad-plugin-links] validating links

...

[docpad-plugin-links] dead links detected!
  >  /index.html : /broken.html ( /broken.html )
[docpad-plugin-links] link validation summary
  > total: 3
  > found: 2
  > ignored: 0
  > dead: 1

Error: Found dead links (see log)
  ...
```

The plugin may optionally fail if invalid document references are used or in-page links are defined twice. 


## Use the Plugin

```
npm install --save docpad-plugin-links
```


## Features

* Generate in-page heading links based on heading text and `<section />` nesting
* Expand `ref:/some/link` and `ref:asset:/assets/img.png` in `<a href />` and `<img src />` to actual link targets
* Collect and report dead links


## Resources

* [Issue Tracker](https://github.com/camunda/docpad-plugin-links/issues)


## Configuration

The plugin may be configured via a plugin configuration entry in the `docpad.conf.js` file:

```javascript
var conf = {
  ...
  plugins: {
    ...
    links: { /* plugin configuration */ }
  }
  ...
}
```

The configuration may look like this

```javascript
{
  validate: {
    // whether to fail if errors are detected
    failOnError: true || false, 

    // a pattern for external files that are to be ignored during link checking
    ignoreTargetPattern: /.*external.*/ || null,
    
    // a pattern for documents to not check for dead links
    ignoreDocumentPattern: /.*summary\.html/
  },
  process: {
    // which headings to process to generate ids for
    headings: [ 'h1', 'h2', 'h3' ],

    // which documents (by meta tag) to include during link generation
    include: [ 'links' ] || 'layouted'

    // which documents (by meta tag) to exclude during link generation
    exclude: [ 'no-link-check' ]
  },
  
  // which log level to use to display output to the user
  logLevel: 'default' || 'performance' || 'debug' || 'none'
}
```


## Usage Details

This gives some details on the functionality provided by the plugin.

### Link Expansion

Lets say you have the document `posts/some-document.md` with `ref:` prefixed links to other documents:

```markdown
---
title: 'Some Document'
---

[Link to other doc](ref:other-document.html)
[Link to introduction](ref:/index.html#section1-introduction)
```

The plugin will make sure that

*   `ref:` prefixed links are expanded to actual document references independant of where `posts/some-document.md` ends up after includes
*   `ref:` links are recorded and checked for validity after built

The resulting html code will look like this:

```html
<a href="other-document.html">Link to other doc</a>
<a href="../index.html#section1-introduction">Link to introduction</a>
```

### Link Expansion in Images

It is possible to expand paths to image urls as well:

```html
<img src="ref:asset:/assets/images/some-image.jpg" />
```

Instead of using `ref:` simply use `ref:asset:` as a prefix to do so. Assuming the document is located under `posts/recent/` the resulting HTML looks like this:

```html
<img src="../../assets/images/some-image.jpg" />
```

### In-page Anchor Generation

Lets say the document `index.html` (linked from `some-document.md`) contains the following code:

```html
---
title: 'Index'
---

<section id="section1">
  <h1>Introduction</h1>
  <p>
    Bla blub.
    <section id="sub1">
      <h2>You did not know this!!$$$</h2>
      <p>
        Special trick.
      </p>
    </section>
  </p>
</section>
```

This plugin will generate in-page anchors for each heading based on its nesting in `<section/>` elements. 

The rules for generation are:

*   concatenate parent section ids and the heading text using dashes
*   slugify the resulting string by
    * removing all non-word characters
    * replacing spaces with dashes
    * lowercasing the result

The resulting HTML code looks like this:

```html
<section id="section1">
  <h1 id="section1-introduction">Introduction</h1>
  <p>
    Bla blub.
    <section id="sub1">
      <h2 id="section1-sub1-you-did-not-know-this">You did not know this!!$$$</h2>
      <p>
        Special trick.
      </p>
    </section>
  </p>
</section>
```

Checkout the [tests](https://github.com/camunda/docpad-plugin-links/tree/master/test/src) for all supported use cases.

### Dead Link Checking

The plugin collects all `ref:` annotated links and validates them against documents and in-page anchors.

If there is a missmatch between referenced and actual defined anchors the plugin will report that as a *dead link*:

```
Dead link in  /posts/mypost.html : /other-post.html ( /other-post.html )
```


## Build the Plugin

```
# install dependencies
npm install
node_modules/.bin/cake test-setup

# create modules
node_modules/.bin/cake dev

# test
node_modules/.bin/cake test
```


## License

[MIT](http://creativecommons.org/licenses/MIT/)
