{requirePackages} = require 'atom-utils'
{CompositeDisposable} = require 'atom'
$ = require 'jquery'

module.exports = TreeViewAutoresize =
  config:
    hover:
      type: 'object'
      order: 1
      properties:
        enabled:
          type: 'boolean'
          title: 'Enabled'
          description: 'Expand the tree-view width when hovering on it, and collapse when you move your mouse off of it'
          default: false
          order: 1
        peek:
          type: 'boolean'
          default: true
          title: 'Peek'
          order: 2
          description: 'Expand the tree view whenever the active file changes'
    minimumWidth:
      type: 'integer'
      default: 0
      order: 2
      description: 'Minimum tree-view width. Put 0 if you don\'t want a min limit.'
    maximumWidth:
      type: 'integer'
      default: 0
      order: 3
      description: 'Maximum tree-view width. Put 0 if you don\'t want a max limit.'

  constructor: ->
    @scrollbarSize = 0

  activate: (state) ->
    @scrollbarSize = @getScrollbarWidth()
    
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.config.observe 'tree-view-autoresize-ide.maximumWidth', (max) => @max = max
    @subscriptions.add atom.config.observe 'tree-view-autoresize-ide.minimumWidth', (min) => @min = min
    requirePackages('tree-view').then ([treeView]) =>
      @treeView = treeView.treeView
      @treeView.on 'click.autoresize', '.directory', (=> @resizeTreeView())
      @subscriptions.add atom.workspace.onDidChangeActivePaneItem => @resizeTreeView(atom.config.get 'tree-view-autoresize-ide.hover.peek')
      @subscriptions.add atom.commands.add 'atom-workspace',
        'tree-view:reveal-active-file': => @resizeTreeView(atom.config.get 'tree-view-autoresize-ide.hover.peek')
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
      @subscriptions.add atom.config.observe 'tree-view-autoresize-ide.hover.enabled', (enable) =>
        @hover(enable, false)
        unless enable
          @stopLoop = true
          atom.config.set('tree-view-autoresize-ide.hover.peek', false)
      @subscriptions.add atom.config.observe 'tree-view-autoresize-ide.hover.peek', (val) =>
        if (not atom.config.get 'tree-view-autoresize-ide.hover.enabled') and val and not @stopLoop
          atom.config.set 'tree-view-autoresize-ide.hover.enabled', true
        else @stopLoop = false

  deactivate: ->
    @subscriptions.dispose()
    @hover(false)
    @treeView?.unbind 'click.autoresize'

  hover: (enable = true, switched = true) ->
    onHover = () =>
      $($('.tree-view').children()).show 300
      @resizeTreeView()
    offHover = () =>
      @treeView.animate {minWidth: @getWidth(20), width: @getWidth(20)}, 200
      $($('.tree-view').children()).hide 300
    if enable
      @treeView.on 'mouseenter', (=> onHover())
      @treeView.on 'mouseleave', (=> offHover())
      offHover() unless switched
    else
      @treeView.unbind 'mouseenter mouseleave'
      onHover()

  # http://stackoverflow.com/a/13382873
  getScrollbarWidth: () ->
    outer = document.createElement("div")
    outer.style.visibility = "hidden"
    outer.style.width = "100px"
    outer.style.msOverflowStyle = "scrollbar" # needed for WinJS apps

    document.body.appendChild(outer)

    widthNoScroll = outer.offsetWidth
    # force scrollbars
    outer.style.overflow = "scroll"

    # add innerdiv
    inner = document.createElement("div")
    inner.style.width = "100%"
    outer.appendChild(inner);       

    widthWithScroll = inner.offsetWidth

    # remove divs
    outer.parentNode.removeChild(outer)

    widthNoScroll - widthWithScroll

  hasVerticalScroll: ->
    scroller = @treeView[0].getElementsByClassName('tree-view-scroller')[0]
    
    return scroller.scrollHeight > scroller.clientHeight

  resizeTreeView: (hoverToggle = false) ->
    @hover(false) if hoverToggle
    setTimeout =>
      currWidth = @treeView.list.outerWidth()

      if currWidth > @treeView.width()
        newWidth = @getWidth(currWidth) + if @hasVerticalScroll() then @scrollbarSize else 0
        
        @treeView.animate {width: newWidth}, 200
      else
        tmp = @treeView.width()
        @treeView.width(1)
        newWidth = @treeView.list.outerWidth()
        @treeView.width(tmp)
        
        newWidth = @getWidth(newWidth) + if @hasVerticalScroll() then @scrollbarSize else 0
        
        @treeView.animate {width: newWidth}, 200
    , 200
    if hoverToggle
      setTimeout =>
        @hover(atom.config.get('tree-view-autoresize-ide.hover.enabled'), false)
      , 1700

  getWidth: (w) ->
    if @max is 0 or w < @max
      if @min is 0 or w > @min
        w;
      else
        @min
    else
      @max
