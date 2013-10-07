# Links plugin for DocPad

A plugin for [DocPad](http://docpad.org) that advanced linking features to DocPad. 


## Features

* Generation of in-page heading links based on heading names and nesting in `<section />` elements
* Expansion of `<a href="ref:/some/link">Link</a>` and `<img src="ref:asset:/assets/img.png" />` to actual link targets
* Dead link checking for `ref:` links


## Install the Plugin

```
npm install --save docpad-plugin-links
```


## Configuration Options

The following configuration options are supported by the plugin:

*   __validateLinks__ = `true` - (`true|false|'report'`) check defined and referenced links
*   __processLayoutedOnly__ = `false` - (`true|false`) process only documents piped through a layout
*   __processFlaggedOnly__ = `false` - (`false|string`) `false` to process all, a `string` to process all documents for which the so named meta-data property is present
*   __logLevel__ = `'default'` - (`'default', 'performance', 'debug', 'none'`)


## Resources

* [Issue Tracker](https://github.com/camunda/docpad-plugin-links/issues)


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
