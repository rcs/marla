# Octospy GitHub events.
#
# Powered by http://developer.github.com/v3/repos/hooks/
#
#
# Environment Variables:
#
# HUBOT_URL             : Where this hubot is mounted (ex "http//hubot.example.com"
# HUBOT_GITHUB_USER     : The github user to use for the API
# HUBOT_GITHUB_PASSWORD : The password to use for the API
#

# TODO:
# add commit_comment support -- requires a round-trip to github to get the commit
# Credentials for github.com and GitHub:FI
# Collapse long commit lists down
# Collapse multiple messages to people in the same room
#
# PIPEDREAM:
# Different templates for markdown/html/text interfaces (campfire/irc) (so we can have gravatars, named links)

_ = require 'underscore'
QS = require 'querystring'
Handlebars = require 'handlebars'

# Internal: Given a template name and a context, return the compiled template.
# Returns JSONed context if no template is found.
#
# event   - The event type we're rendering
# context - The object to give the template
#
# If the template in the views hash is a function, pass it the context to get the specific template
renderTemplate = (event,context) ->
  if views[event]
    if _.isFunction(views[event])
      str = views[event](context)
    else
      str = views[event]
      template = Handlebars.compile(str)
      message = template(context)
  else
    # We couldn't find a template, so let's push this out. People on github like JSON, right?
    message = {}
    message[event] = req.body
    message = JSON.stringify message

  return message

# Private: Helper method for pubsub modification.
#
# msg    - The hubot msg object, used for its http client
# action - The action to take, 'subscribe' or 'unsubscribe'
# target - The hash containing the subscription we want to work on
#          github_url - The base github URL
#          repo       - The repository
#          event      - The event type
# cb     - Function to pass as a callback to the HTTP call
#
# Example:
#
# pubsub_modify(msg, 'subscribe', { github_url: 'github.com', repo: 'github/hubot', event: 'push' }, (err,resp,body) -> msg.send "aaaaaallllright.")
#
pubsub_modify = (msg, action, target, cb) ->
  {github_url, repo, event} = target

  data = QS.stringify {
    "hub.mode": action,
    "hub.topic": "https://#{github_url}/#{repo}/events/#{event}.json"
    "hub.callback": "#{process.env.HUBOT_URL}/hubot/octospy/#{github_url}/#{event}"
  }

  msg.http("https://api.#{github_url}")
    .path('/hub')
    # The .auth call in scoped-http-client wasn't working -- I was probably doing something wrong.
    .header('Authorization', 'Basic ' + new Buffer("#{process.env.HUBOT_GITHUB_USER}:#{process.env.HUBOT_GITHUB_PASSWORD}").toString('base64'))
    .post(data) cb


# These are views for each of the event types.
# Note: Handlebars likes to HTML escape things. It's kinda lame as a default. {{{ }}} to avoid it.
views =
  push:
    """
      {{pusher.name}} pushed to {{branch}} at {{repo_name}} {{compare}}
      {{#each commits}}  {{author.username}}: {{id}} {{{message}}}
      {{/each}}
    """
  issues:
    """
      {{sender.login}} {{action}} issue {{issue.number}} on {{repo_name}} "{{{issue.title}}}" {{issue.html_url}}
    """
  issue_comment:
    """
      {{sender.login}} commented on issue {{issue.number}} on {{repo_name}} "{{{issue.title}}}" {{issue.html_url}}
      > {{{comment.body}}}
    """
  pull_request: (context) ->

    return switch context.action
      when 'opened'
        """
          {{sender.login}} {{action}} pull requst {{number}} on {{repo_name}}: "{{{pull_request.title}}}" {{pull_request.html_url}}
          {{pull_request.commits}} commits with {{pull_request.additions}} additions and {{pull_request.deletions}} deletions
        """
      when 'closed'
        switch context.pull_request.merged
          when true
            """
              {{sender.login}} merged pull requst {{number}} on {{repo_name}}: "{{{pull_request.title}}}" {{pull_request.html_url}}
            """
          else
            """
              {{sender.login}} closed pull requst {{number}} on {{repo_name}} without merging: "{{{pull_request.title}}}" {{pull_request.html_url}}
            """
      when 'synchronize'
        """
          {{sender.login}} updated pull requst {{number}} on {{repo_name}}: "{{{pull_request.title}}}" {{pull_request.html_url}}
        """

  gollum:
    """
      {{#each pages}}
        {{../sender.login}} {{action}} wiki page on {{repo_name}}: "{{{title}}}" {{html_url}}
      {{/each}}
    """
  watch:
    """
      {{sender.login}} started watching {{repo_name}} http://{{github_url}}/{{sender.login}}
    """
  download:
    """
      {{sender.login}} added a download to {{repo_name}}: {{{download.name}}} {{download.html_url}}
    """
  fork:
    """
      {{sender.login}} forked {{repo_name}} {{forkee.html_url}}
    """
  fork_apply:
    """
      {{sender.login}} merged from the fork queue to {{head}} on {{repo_name}}
    """
  member:
    """
      {{sender.login}} added {{member.login}} as a collaborator to {{repo_name}}
    """
  public:
    """
      {{sender.login}} turned {{repo_name}} public
    """



module.exports = (robot) ->

  # Internal: Initialize our brain
  robot.brain.on 'loaded', =>
    robot.brain.data.octospy ||= {}

  # Public: Announce the kinds of things octospy knows about
  robot.respond /octospy events/, (msg) ->
    msg.reply "I know about " + ( event for event of views ).join(', ')

  # Public: Dump the watching hash
  robot.respond /octospying/, (msg) ->
    watching = []

    # Troll octospy's data for any possible listeners, then see if they're us
    for github_url, github of robot.brain.data.octospy
      for repo_name, repo of github
        for event, listeners of repo
          if _.include(listeners, msg.message.user.id)
            watching.push
              github: github_url
              repo_name: repo
              event: event

    if watching.length > 0
      msg.reply (for sub in watching
        "#{repo_name} #{event} events" + if github_url != 'github.com'
            "on #{github}"
          else
            ""
      )
    else
      msg.reply "I don't think you're octospying anything"


  # Public: Unsubscribe from an event type for a repository
  #
  # repo       - The repository name (ex. 'github/hubot'
  # event      - The event type to stop watching (default: 'push')
  # github_url - The base github URL (default: 'github.com'
  robot.respond /octospy stop ([^ ]+\/[^ ]+) ?([^ ]*)? ?([^ ]*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    # Convenience accessors with initialization
    repos = robot.brain.data.octospy[github_url] || = {}
    events = repos[repo] ||= {}
    listeners = events[event] ||= []

    msg.reply "Unoctospying #{repo} #{event} events on #{github_url}"

    if listeners.length == 0
      return msg.send "Can't find any octospies for #{repo} #{event} events"

    # Find the user in possible listeners
    for listener, i in listeners
      if _.isEqual(listener,msg.message.user)
        removed = listeners.splice(i,1)

    # Didn't find the user
    if ! removed
      return msg.send "I don't think you're octospying #{repo} #{event} events"


    # If nobody's listening, we should unregister.
    if listeners.length == 0
      pubsub_modify msg, 'unsubscribe', { github_url: github_url, repo: repo, event: event },
        (err,res,body) ->
          switch res.statusCode
            when 200
              delete events[event]
              msg.reply "You were the last. Removed my subscription to #{repo} #{event} events"
            else
              msg.send "Failed to unsubscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"

  # Public: Subsribe to an event type for a repository
  #
  # repo       - The repository name (ex. 'github/hubot'
  # event      - The event type to stop watching (default: 'push')
  # github_url - The base github URL (default: 'github.com'
  robot.respond /octospy ([^ ]+\/[^ ]+) ?([^ ]*)? ?([^ ]*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    if ! _.include(( event for event of views ), event)
      return msg.reply "Sorry, I don't know about #{event}"

    # Convenience accessors with initialization
    repos = robot.brain.data.octospy[github_url] || = {}
    events = repos[repo] ||= {}
    listeners = events[event] ||= []


    # Internal: Add a listener
    #
    # Closes around msg, repo, event, github_url
    add_listener = ->
      if ! _.include(listeners, msg.message.user_ud)
        listeners.push msg.message.user.id
        msg.reply "Octospying #{repo} #{event} events on #{github_url}"
      else
        msg.reply "You're already octospying that."

    # Check to see if we have any subscriptions to this event type for the
    # repo, and if not, register the subscription
    if listeners.length == 0
      pubsub_modify msg, 'subscribe', { github_url: github_url, repo: repo, event: event },
        (err,res,body) ->
          switch res.statusCode
            when 204
              add_listener()
            when 422
              msg.reply "Either #{repo} doesn't exist, or #{process.env.HUBOT_GITHUB_USER} isn't a collaborator on it. Couldn't subscribe."
            else
              msg.reply "I failed to subscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"
    else
      add_listener()




  # Public: Repond to POSTs from github
  #
  # :github - The github base url we registered, so we know the source of this POST
  # :event  - The event type that was registered
  robot.router.post '/hubot/octospy/:github/:event', (req, res) ->
    req.body = req.body || {}

    return res.end "ok" unless req.body.repository # Not something we care about. Who does this?

    # Convenience accessors
    event = req.params.event
    repo_name =  (req.body.repository.owner.login || req.body.repository.owner.name) + "/" + req.body.repository.name
    github_url = req.params.github


    # Extend the context for our templates
    context = _.extend req.body,
      repo: req.body.repository
      repo_name: repo_name
      github_url: github_url
      branch: if req.body.ref
          req.body.ref.replace(/^refs\/heads\//,'')
        else
          undefined

    message = '[octospy] ' +  renderTemplate(event,context)

    # Tell the people who care
    listeners = robot.brain.data.octospy[github_url]?[repo_name][event] || []
    for listener in listeners when listener
      robot.send robot.userForId(listener), message.split("\n")...

    res.end "ok"
