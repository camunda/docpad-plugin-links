# links plugin for Docpad
module.exports = (BasePlugin) ->

  log = 
    debug: (->) # console.log
    info: console.log
    warn: console.log


  # -------------------------
  # requires
  jsdom = require('jsdom')
  jquery = require('jquery');

  {Task,TaskGroup} = require('taskgroup')

  # --------------------------
  # extension libraries
  docToSource = (document, html) ->
    if html
      (document.doctype || '').toString() + document.innerHTML
    else
      document.body.innerHTML


  linkify = (str) ->
    str.toLowerCase()
       .replace(/[\s]+/g, '-')
       .replace(/[^\w-]/g, '')


  getTime = -> new Date().getTime()


  compactUrl = (url) ->
    newUrl

    while true
      newUrl = url.replace(/[^\.\/]+\/\.\.\//, '')
      # apply ../ consumption only if no parents are given 
      # (the ../../../../foo -> /foo case)
      newUrl = url.replace(/\.\.\//, '') if newUrl == url

      break if newUrl == url

      url = newUrl

    # finally replace redundant ./
    newUrl.replace(/\.\//g, '')


  # console.log('/a/b/.././', compactUrl('/a/b/.././'))
  # console.log('/a/b/.././foo.html', compactUrl('/a/b/.././foo.html'))
  # console.log('/a/b/../../../', compactUrl('/a/b/../../../'))
  # console.log('/nested/./', compactUrl('/nested/./'))

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
      if u.match(/\.html$/)
        if u.match(/\/index.html$/)
          url = u.replace('index.html', '')
        else
          url = u

    url

  # --------------------------
  # plugin definition
  class LinkPlugin extends BasePlugin
    
    # ----------------------------
    # plugin name
    name: 'links'


    # ----------------------------
    # default configuration
    config:
      validateLinks: true # (true|false|'report') check defined and referenced links
      processLayoutedOnly: false # (true|false) process only documents piped through a layout
      processFlaggedOnly: false # (false|string) false to process all, a string to process all documents for which the so named meta-data property is present


    # -----------------------------
    # initialize

    # Prepare our Configuration
    constructor: ->
      # Prepare
      super
     
      config = @getConfig()

      throw 'Configuration property processFlaggedOnly must be false|string' if config.processFlaggedOnly == true

      @clear()


    clear: ->

      @links = {}
      @references = []


    addLink: (link, documentUrl, document) ->
      log.debug 'add link', link, documentUrl

      config = @getConfig()
      fullLink = link

      switch link.charAt(0)
        when '?', '#'
          fullLink = documentUrl + link

      if @links[fullLink]
        msg = 'Link defined twice: <' + link + '> (' + fullLink + ')'
        if config.validateLinks != 'report'
          throw new Error(msg)
        else
          log.warn msg

      @links[fullLink] = 
        link: link
        fullLink: fullLink
        documentUrl: documentUrl
        document: document


    addReference: (ref, documentUrl, document) ->
      log.debug 'add ref', ref, documentUrl

      fullRef = ref

      switch ref.charAt(0)
        when '#'
          fullRef = compactUrl(documentUrl + ref)
        when '/' then
        when '?' then
        else
          # concat ref for relative links (not for http:// or https://)
          fullRef = compactUrl(level(documentUrl) + ref) unless ref.match(/^http(s)?:\/\//)

      reference = 
        ref: ref
        fullRef: fullRef
        documentUrl: documentUrl
        document: document

      @references.push(reference)


    validateLinkRefs: (mode) ->

      links = @links
      references = @references

      total = notFound = found = 0

      log.info 'Validating links...'

      references.forEach (e) ->
        if links[e.fullRef]
          found++
        else
          notFound++
          log.warn 'Dead link in ', e.documentUrl, ':', e.ref, '(', e.fullRef, ')'

        total++

      log.info 'Finished.'
      log.info '-- total:', total, 'found:', found, 'dead:', notFound

      throw new Error('Found dead links (see log).') if notFound && mode != 'report'


    processDocument: (document, complete) ->

      config = @getConfig()

      url = getDocumentUrl(document)
      pathSeparator = createPathSeparator(url)

      content = document.get('contentRendered')
      contentWithoutLayout = document.get('contentRenderedWithoutLayout')

      extension = document.get('outExtension')

      log.debug 'Processing', url, pathSeparator, extension

      return complete() if extension != 'html' || !content

      # render only documents that have been piped through a layout
      # (saves performance)
      if config.parseLayoutedOnly && content == contentWithoutLayout
        log.debug 'Skipping document (parseLayoutedOnly)'
        return complete()

      if config.processFlaggedOnly && !document.meta.get(config.processFlaggedOnly)
        log.debug 'Skipping document (processFlaggedOnly)'
        return complete()

      html = !!content.match(/.*<\/html>\s*$/)

      registry = @

      registry.addLink(url, url, document) if config.validateLinks

      createHeadingRefs = ($) ->
        $('h1, h2, h3, h4').each ->
          e = $(this)
          id = e.attr('id')

          # do not re-assign ids
          unless id

            sections = e.parents('section')

            id = linkify(e.text())
            sections.each -> 
              section = $(this)
              sectionId = section.attr('id')

              # no sectionId -> break
              return unless sectionId

              id = linkify(sectionId) + '-' + id;

            log.debug 'assign id <', id, '> to heading <', e.text(), '>'
            e.attr('id', id)

          # log link
          registry.addLink('#' + id, url, document) if config.validateLinks

      
      resolveLinkRefs = ($) ->
        $('a').each ->
          a = $(this)
          href = a.attr('href')

          return if !href || href.indexOf(REF_STR) != 0

          originalHref = href = href.substring(REF_STR.length)
          
          # handle absolute link
          if href.charAt(0) == '/'
            href = pathSeparator + href.substring(1)

          log.debug 'replace <', a.attr('href'), '> with <', href, '>'

          a.attr('href', href)

          # log reference
          registry.addReference(originalHref, url, document) if config.validateLinks

      jsdom.env
        html: content
        done: (err, window) -> 
          
          log.warn 'error parsing HTML', err if err

          complete(err) if err

          $ = jquery.create(window);

          createHeadingRefs($)
          resolveLinkRefs($)

          content = docToSource(window.document, html)

          log.debug 'processed document contents'
          log.debug content
          log.debug '\n\n'

          document.set({
            contentRendered: content
          });
          
          log.debug content
          log.debug '\n\n'
          
          complete()


    # -----------------------------
    # Events

    writeBefore: (opts, next) ->
      config = @getConfig()
      time = getTime()

      log.info 'Checking documents...'

      { collection, templateData } = opts
      
      linker = @

      tasks = new TaskGroup().setConfig(concurrency: 0).once 'complete', ->
        log.info 'Done in ', (getTime() - time), 'ms.'

        linker.validateLinkRefs(config.validateLinks) if config.validateLinks
        next()

      collection.forEach (d) ->
        tasks.addTask (complete) ->
          linker.processDocument(d, complete)

      # Run the tasks
      tasks.run()

      # Chain
      @

    writeAfter: (collection) ->
      @clear()


  REF_STR = "ref:"

  return LinkPlugin