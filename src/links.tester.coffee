# plugin tester
module.exports = (testers) ->

  class LinksPluginTester extends testers.RendererTester

    # tester config
    config:
      contentRemoveRegex: /(\\r|\\n|\\t|\s\s)+/g

    # docpad config
    docpadConfig:
      logLevel: 5
      renderPasses: 2
      enabledPlugins:
        'eco': true
        'marked': true
      plugins:
        links: 
          logLevel: 'debug'