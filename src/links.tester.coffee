# plugin tester
module.exports = (testers) ->

  class LinksPluginTester extends testers.RendererTester

    # tester config
    config:
      contentRemoveRegex: /[\r]+/g

    # docpad config
    docpadConfig:
      logLevel: 5
      renderPasses: 2
      enabledPlugins:
        'eco': true
        'marked': true
      plugins:
        links: 
          process: 
            exclude: [ 'include', 'performanceTest' ]
          validate: 
            ignorePattern: /.*ignored.*/
          logLevel: 'debug'

#  class LinksPluginPerformanceTester extends testers.RendererTester
#
#    # tester config
#    config:
#      contentRemoveRegex: /[\r]+/g
#   
#    # docpad config
#    docpadConfig:
#      logLevel: 5
#      renderPasses: 2
#      enabledPlugins:
#        'eco': true
#        'marked': true
#      plugins:
#        links: 
#          process: { include: [ 'performanceTest' ], exclude: [ 'include' ] }
#          logLevel: 'info'