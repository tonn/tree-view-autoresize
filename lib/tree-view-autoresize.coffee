{requirePackages} = require 'atom-utils'
{CompositeDisposable} = require 'atom'
$ = require 'jquery'

module.exports = TreeViewAutoresize =
  config:
    minimumWidth:
      type: 'integer'
      default: 0
      description:
        'Minimum tree-view width. Put 0 if you don\'t want a min limit.'
    maximumWidth:
      type: 'integer'
      default: 0
      description:
        'Maximum tree-view width. Put 0 if you don\'t want a max limit.'
    hover:
      type: 'boolean'
      default: false
      description:
        'Expand the tree-view width when hovering on it, and collapse when you move your mouse off of it'

  subscriptions: null
  max: 0
  min: 0

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.config.observe 'tree-view-autoresize.maximumWidth',
      (max) =>
        @max = max

    @subscriptions.add atom.config.observe 'tree-view-autoresize.minimumWidth',
      (min) =>
        @min = min

    if atom.packages.isPackageLoaded 'nuclide-file-tree'
      $('body').on 'click.autoresize', '.nuclide-file-tree .directory', (e) =>
        @resizeNuclideFileTree()
      @subscriptions.add atom.project.onDidChangePaths (=> @resizeNuclideFileTree())
      @resizeNuclideFileTree()
    else
      requirePackages('tree-view').then ([treeView]) =>
        @treeView = treeView.treeView
        @treeView.on 'click.autoresize', '.directory', (=> @resizeTreeView())
        @subscriptions.add atom.workspace.onDidChangeActivePaneItem => @resizeTreeView(true)
        @subscriptions.add atom.commands.add 'atom-workspace',
          'tree-view:reveal-active-file': => @resizeTreeView(true)
        @subscriptions.add atom.commands.add '.tree-view',
          'tree-view:open-selected-entry': => @resizeTreeView()
          'tree-view:expand-item': => @resizeTreeView()
          'tree-view:recursive-expand-directory': => @resizeTreeView()
          'tree-view:collapse-directory': => @resizeTreeView()
          'tree-view:recursive-collapse-directory': => @resizeTreeView()
          'tree-view:move': => @resizeTreeView()
          'tree-view:cut': => @resizeTreeView()
          'tree-view:paste': => @resizeTreeView()
          'tree-view:toggle-vcs-ignored-files': => @resizeTreeView()
          'tree-view:toggle-ignored-names': => @resizeTreeView()
          'tree-view:remove-project-folder': => @resizeTreeView()
        @subscriptions.add atom.config.observe 'tree-view-autoresize.hover', (enable) =>
          @hover(enable)
          @switched = false


  deactivate: ->
    @subscriptions.dispose()
    @hover(false)
    @treeView?.unbind 'click.autoresize'
    $('body').unbind 'click.autoresize'

  serialize: ->


  hover: (enable = true) ->
    if enable
      unless @switched
        @treeView.animate {minWidth: @getWidth(20), width: @getWidth(20)}, 200
        @switched = true
      @treeView.on 'mouseenter', (=> @resizeTreeView())
      @treeView.on 'mouseleave', (=> @treeView.animate {width: @getWidth(20)}, 200)
    else
      @switched = true
      @treeView.unbind 'mouseenter mouseleave'
      @resizeTreeView()

  resizeTreeView: (hoverToggle = false) ->
    @hover(false) if hoverToggle
    setTimeout =>
      currWidth = @treeView.list.outerWidth()
      if currWidth > @treeView.width()
        @treeView.animate {width: @getWidth(currWidth)}, 200
      else
        @treeView.width 1
        @treeView.width @treeView.list.outerWidth()
        newWidth = @treeView.list.outerWidth()
        @treeView.width currWidth
        @treeView.animate {width: @getWidth(newWidth)}, 200
    , 200
    if hoverToggle
      setTimeout =>
        @switched = false
        @hover(atom.config.get('tree-view-autoresize.hover'))
      , 1700

  resizeNuclideFileTree: ->
    setTimeout =>
      fileTree = $('.tree-view-resizer')
      currWidth = fileTree.find('.nuclide-file-tree').outerWidth()
      if currWidth > fileTree.width()
        fileTree.animate {width: @getWidth(currWidth + 10)}, 200
      else
        fileTree.width 1
        fileTree.width fileTree.find('.nuclide-file-tree').outerWidth()
        newWidth = fileTree.find('.nuclide-file-tree').outerWidth()
        fileTree.width currWidth
        fileTree.animate {width: @getWidth(newWidth + 10)}, 200
    , 200

  getWidth: (w) ->
    if @max is 0 or w < @max
      if @min is 0 or w > @min
        w
      else
        @min
    else
      @max
