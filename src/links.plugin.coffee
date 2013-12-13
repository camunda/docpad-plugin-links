# links plugin for Docpad
module.exports = (BasePlugin) ->

  # -------------------------
  # requires
  htmlparser = require('htmlparser2');

  {Task,TaskGroup} = require('taskgroup')

  # -------------------------
  # regex cache
  REGEX_DIR_UP_CONSUME = /[^\.\/]+\/\.\.\//
  REGEX_DIR_UP = /\.\.\//
  REGEX_DIR_CURRENT_ALL = /\.\//g
  REGEX_NON_WORD_ALL = /[^\w-]+/g
  REGEX_SPACES_ALL = /[\s]+/g
  REGEX_HTTP_S = /^http(s)?:\/\//
  REGEX_HTML_DOC = /.*<\/html>\s*$/

  # -------------------------
  # log utility
  log = 
    debug: (->)
    fine: (->)
    performance: (->)
    info: console.log
    warn: console.log

  # --------------------------
  # utility functions
  # --------------------------

  docToSource = (document, html) ->
    if html
      (document.doctype || '').toString() + document.innerHTML
    else
      document.body.innerHTML


  linkify = (str) ->
    str.trim()
       .replace(REGEX_SPACES_ALL, '-')
       .replace(REGEX_NON_WORD_ALL, '')
       .toLowerCase()


  endsWith = (str, searchString, position) ->
    position = position || str.length
    position = position - searchString.length
    lastIndex = str.lastIndexOf(searchString)
    return lastIndex != -1 && lastIndex == position


  getTime = -> new Date().getTime()


  compactUrl = (url) ->
    newUrl

    while true
      newUrl = url.replace(REGEX_DIR_UP_CONSUME, '')
      # apply ../ consumption only if no parents are given 
      # (the ../../../../foo -> /foo case)
      newUrl = url.replace(REGEX_DIR_UP, '') if newUrl == url

      break if newUrl == url

      url = newUrl

    # finally replace redundant ./
    newUrl.replace(REGEX_DIR_CURRENT_ALL, '')


  level = (url) ->
    idx = url.lastIndexOf('/')

    if idx == -1
      return '/'
    else
      return url.substring(0, idx + 1)


  createPathSeparator = (url) ->
    parts = url.split('/')

    levels = parts.length - 1

    separator = while levels -= 1
      '../' 

    separator.join('')


  getDocumentUrl = (document) ->
    urls = document.get('urls')
    url = document.get('url')

    urls.forEach (u) ->
      if endsWith(u, '.html')
        if endsWith(u, '/index.html')
          url = u.substring(0, u.length - 'index.html'.length)
        else
          url = u

    url

  # --------------------------
  # plugin definition
  class LinkPlugin extends BasePlugin
    
    # ----------------------------
    # plugin name
    name: 'links'


    ##
    # default configuration
    #
    config:

      # link validation options
      # false || object
      validate: 
        ignorePattern: null # pattern to be ignored when validating dead links
        failOnError: true # whether to fail with an error if link validation detects a problem

      # link generate options
      # false || object
      process:
        include: null # layouted || [ tags ... ]
        exclude: null # [ tags ... ]
        overrideRefs: true # if heading refs should be re-generated

      # logging level with which to output data
      logLevel: 'default'

    ##
    # process: 'all'
    # process: 'layouted'
    # process: { include: [ 'performance' ], exclude: [ 'foo' ] }

    # -----------------------------
    # initialize

    # Prepare our Configuration
    constructor: ->
      # Prepare
      super
     
      config = @getConfig()
      process = config.process
      validate = config.validate

      log.fine '[docpad-plugin-links] init configuration'
      log.fine '  > process', process
      log.fine '  > validate', validate

      log.debug = console.log if config.logLevel == 'debug'
      log.fine = console.log if config.logLevel == 'performance' || config.logLevel == 'fine' || config.logLevel == 'debug'
      log.performance = console.log if config.logLevel == 'performance'

      if config.logLevel == 'none'
        log.warn = (->)
        log.info = (->)

      isHtmlFile = (document) -> document.get('outExtension') == 'html' && !!document.get('contentRendered')

      isLayouted = (document) -> 
        document.get('contentRendered') != document.get('contentRenderedWithoutLayout')

      matchesFlagged = (filter) ->
        (document) ->
          match = true

          if filter.include
            includedMatch = (true for tag in filter.include when document.meta.get(tag))
            match = match && includedMatch.length > 0

          if filter.exclude
            excludedMatch = (true for tag in filter.exclude when !!document.meta.get(tag))
            match = match && excludedMatch.length == 0

          match

      if !process
        @applyTo = (document) -> false

      else if process == 'all' || (!process.include || process.include == 'all')
        @applyTo = (document) -> 
          isHtmlFile(document)

      else if process == 'layouted' || process.include == 'layouted'
        @applyTo = (document) -> 
          isHtmlFile(document) && isLayouted(document)

      else
        isFlagged = matchesFlagged(process)

        @applyTo = (document) -> 
          isHtmlFile(document) && isFlagged(document)

      @clear()


    clear: ->
      @links = {}
      @references = []


    addLink: (link, documentUrl, document) ->
      log.debug '  > add link', link

      config = @getConfig()
      fullLink = link

      switch link.charAt(0)
        when '?', '#'
          fullLink = documentUrl + link

      if @links[fullLink]
        msg = 'Link defined twice: <' + link + '> (' + fullLink + ')'
        if config.validate.failOnError
          throw new Error('[docpad-plugin-links] ' + msg)
        else
          log.warn msg

      @links[fullLink] = 
        link: link
        fullLink: fullLink
        documentUrl: documentUrl
        document: document


    addReference: (ref, documentUrl, document) ->
      log.fine '  > add ref', ref

      fullRef = ref

      switch ref.charAt(0)
        when '#'
          fullRef = compactUrl(documentUrl + ref)
        when '/' then
        when '?' then
        else
          # concat ref for relative links (not for http:// or https://)
          fullRef = compactUrl(level(documentUrl) + ref) unless ref.match(REGEX_HTTP_S)

      reference = 
        ref: ref
        fullRef: fullRef
        documentUrl: documentUrl
        document: document

      @references.push(reference)


    validateLinkRefs: (validateConfig) ->

      links = @links
      references = @references

      ignorePattern = validateConfig.ignorePattern

      @summary = { deadLinks: [] }

      deadLinks = @summary.deadLinks

      total = notFound = found = ignored = 0

      log.info '[docpad-plugin-links] validating links'

      references.forEach (e) ->
        if ignorePattern && ignorePattern.test(e.fullRef)
          ignored++
        else if links[e.fullRef]
          found++
        else
          notFound++
          deadLinks.push({ documentUrl: e.documentUrl, ref: e.ref, fullRef: e.fullRef })

        total++

      @summary.total = total
      @summary.found = found
      @summary.ignored = ignored
      @summary.notFound = notFound


    processDocument: (document, complete) ->
      config = @getConfig()

      url = getDocumentUrl(document)
      pathSeparator = createPathSeparator(url)

      content = document.get('contentRendered')

      time = getTime()

      unless @applyTo(document)
        log.fine '[docpad-plugin-links] skipping', url
        return complete()

      log.fine '[docpad-plugin-links] processing', url
      registry = @

      registry.addLink(url, url, document) if config.validate


      ##
      # Create a heading reference based on heading text and the parent sections
      # 
      createHeadingRef = (sections, headingText) ->

        parts = (linkify(section.id) for section in sections when section.id)
        parts.push(linkify(headingText))

        parts.join('-')


      ##
      # Create patch for parser state
      #
      createPatch = (parser, patchAttrs, selfClosing) ->
        { position: getMatchPosition(parser), tagname: parser._tagname, attrs: patchAttrs, selfClosing: !!selfClosing }

      
      ##
      # Create a string for a html tag
      #
      tagStr = (tagname, attrs, selfClosing) ->
        str = '<' + tagname;
        str += ' ' + ((key + '="' + value + '"') for key, value of attrs).join(' ')
        str += ' /' if selfClosing
        str += '>'

        str


      ##
      # Apply the given patch on the target string
      #
      applyPatch = (str, patch) ->
        replacement = tagStr(patch.tagname, patch.attrs, patch.selfClosing)

        str.substring(0, patch.position.start) + replacement + str.substring(patch.position.end + 1)


      ##
      # Return the match position based on the parsers internal state
      #
      getMatchPosition = (parser) ->
        start = parser.startIndex
        start = 0 if start == 1

        end = parser.endIndex

        { start: start, end: end }

      patches = []
      sections = []

      heading = null


      ##
      # Collects heading text and refs, 
      # patches the heading id unless already present
      # creates new heading ref from (parent sections, heading text) unless present
      # 
      headingsHandler = 
        open: (attrs, parser, tagname) ->
          if attrs.id && !config.process.overrideRefs
            registry.addLink('#' + attrs.id, url, document) if config.validate
          else
            heading = createPatch(parser, attrs)
            heading.text = ''

            # add to patched element list
            patches.push(heading)

        close: (parser) ->
          return unless heading

          ref = createHeadingRef(sections, heading.text)
          heading.attrs['id'] = ref

          registry.addLink('#' + ref, url, document) if config.validate

          heading = null

        text: (text, parser) ->
          return unless heading
          heading.text += text


      ##
      # Keeps track of section nesting
      # 
      sectionHandler = 
        open: (attrs, parser) ->
          sections.push({ id: attrs['id']})
        close: (parser) ->
          sections.pop()


      ##
      # Checks for a[href] attributes that specify ref:[asset:]some-link hrefs
      # and logs / resolves them respectively
      # 
      linkHandler = 
        open: (attrs, parser) ->
          href = attrs.href;

          return unless href && href.indexOf(REF_STR) == 0
          
          # remove :ref part
          href = href.substring(REF_STR.length)
          
          # remove :asset part
          if href.indexOf(ASSET_STR) == 0
            asset = true
            href = href.substring(ASSET_STR.length)
          
          # remember original href
          originalHref = href

          # handle absolute link
          if href.charAt(0) == '/'
            href = pathSeparator + href.substring(1)

          log.debug '  > replace <', attrs.href, '> with <', href, '>'

          attrs.href = href

          patches.push(createPatch(parser, attrs))

          # log reference
          registry.addReference(originalHref, url, document) if config.validate && !asset


      ##
      # Checks for img[src] that specify ref:asset:asset-path links to images
      # and resolves them 
      #
      imageHandler =
        open: (attrs, parser) ->
          src = attrs.src

          return unless src && src.indexOf(ASSET_REF_STR) == 0

          # remove :ref:asset part
          originalSrc = src = src.substring(ASSET_REF_STR.length)
          
          # handle absolute link
          if src.charAt(0) == '/'
            src = pathSeparator + src.substring(1)

          log.debug '  > replace <', attrs.src, '> with <', src, '>'

          attrs.src = src

          patches.push(createPatch(parser, attrs, true))

      handlers =
        h1: headingsHandler,
        h2: headingsHandler,
        h3: headingsHandler,
        h4: headingsHandler,
        section: sectionHandler,
        a: linkHandler,
        img: imageHandler

      textHandlers = []

      parser = new htmlparser.Parser(
        onopentag: (tagname, attrs) ->
          handler = handlers[tagname]
          return unless handler && handler.open

          handler.open(attrs, parser, tagname)
          textHandlers.push(handler) if handler.text

        ontext: (text) -> 
          (handler.text(text, parser) for handler in textHandlers)

        onclosetag: (tagname) ->
          handler = handlers[tagname]
          return unless handler

          textHandlers.pop() if handler.text
          handler.close(parser, tagname) if handler.close
      );
      
      t1 = getTime()

      try
        parser.write(content)
        parser.end()
      catch e
        log.warn '[docpad-plugin-links]', e
        return complete(e)

      t2 = getTime()

      changes = patches.length

      content = applyPatch(content, patch) while patch = patches.pop()

      if changes
        log.debug '  > patched document with ', changes, 'changes'
        log.debug '----'
        log.debug content
        log.debug '----'
        log.debug '\n\n'
      else
        log.debug '  > no changes'

      document.set({
        contentRendered: content
      })

      t3 = getTime()

      log.performance 'time', (t2 - t1), (t3 - t2), (t3 - t1), url
      
      return complete()

    # -----------------------------
    # Events

    writeBefore: (opts, next) ->

      config = @getConfig()
      time = getTime()

      log.info '[docpad-plugin-links] processing documents'

      { collection, templateData } = opts
      
      linker = @

      tasks = new TaskGroup().setConfig(concurrency: 0).once 'complete', ->
        log.info '[docpad-plugin-links] completed in', (getTime() - time), 'ms'

        linker.validateLinkRefs(config.validate) if config.validate
        next()

      collection.forEach (d) ->
        tasks.addTask (complete) ->
          linker.processDocument(d, complete)

      # Run the tasks
      tasks.run()

      # Chain
      @

    writeAfter: (collection) ->

      validate = @config.validate

      if validate
        summary = @summary
        deadLinks = summary.deadLinks

        total = summary.total
        found = summary.found
        notFound = summary.notFound
        ignored = summary.ignored
        
        if deadLinks.length
          log.warn '[docpad-plugin-links] dead links detected!'
          deadLinks.forEach (link) ->
            log.warn '  > ', link.documentUrl, ':', link.ref, '(', link.fullRef, ')'

        log.info '[docpad-plugin-links] link validation summary'

        log.info '  > total:', total
        log.info '  > found:', found
        log.info '  > ignored:', ignored
        log.info '  > dead:', notFound

        throw new Error('Found dead links (see log).') if notFound && validate.failOnError

      @clear()


  REF_STR = 'ref:'
  ASSET_STR = 'asset:'
  ASSET_REF_STR = 'ref:asset:'

  return LinkPlugin