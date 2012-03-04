# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set
#
# Environment Variables:
#
# PREFIX_URL  : The place where this hubot is mounted (ex "http//hubot.example.com"
# GITHUB_USER : The github user to use for the API
# GITHUB_USER : The password to use for the API
#
#

# TODO: 
# add commit_comment support -- requires a round-trip to github to get the commit
# add pull_request support -- helpers necessary for opened/closed/synchronized display --- Sub templates? :-( (Not so bad, can switch on "action", thanks GH!")
#
#

QS = require 'querystring'
Handlebars = require 'handlebars'

EVENTS = ['push','issues']


# Note: Handlebars likes to HTML escape things. It's kinda lame as a default. {{{ }}} to avoid it.
views =
  push:
    """
      [{{repo_name}}] {{pusher.name}} pushed to {{branch}} {{compare}}"
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
      {{{comment.body}}}
    """
  pull_request:
    """
      {{sender.login}} {{action}} pull requst {{number}} on {{repo_name}}: "{{{pull_request.title}}}" {{pull_request.html_url}}
      {{pull_request.commits}} commits with {{pull_request.additions}} additions and {{pull_request.deletions}} deletions
    """
  pull_request_opened:
    """
      {{sender.login}} {{action}} pull requst {{number}} on {{repo_name}}: "{{{pull_request.title}}}" {{pull_request.html_url}}
      {{pull_request.commits}} commits with {{pull_request.additions}} additions and {{pull_request.deletions}} deletions
    """
  pull_request_closed:
    # Can check pull_request.merged to see if it was merged.
    # Merger info in pull_request.merged_by
    """
      {{sender.login}} {{action}} pull requst {{number}} on {{repo_name}}: "{{{pull_request.title}}}" {{pull_request.html_url}}
    """
  pull_request_synchronized:
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
  _ = require('underscore')

  room_or_user = (user) ->


  # Public: Dump the subscriptions hash
  robot.respond /gh_hooks subscriptions/, (msg) ->
    msg.send JSON.stringify robot.brain.data.gh_hooks

  # Public: Unsubscribe from an event type for a repository
  robot.respond /gh_hooks unsubscribe (.*) (.*)? (.*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    # Convenience accessors with initialization
    repos = robot.brain.data.gh_hooks[github_url] || = {}
    events = repos[repo] ||= {}
    listeners = events[event] ||= []

    msg.send "Unsubscribing to #{repo} #{event} events on #{github_url}"

    removing_listener = ->
      if ! listeners.some((elem) ->
        _.isEqual(elem,msg.message.user)
      )
        listeners.push msg.message.user

      msg.send "Subscribed to #{repo} #{event} events on #{github_url}"

    if listeners.length == 0
      return msg.send "Can't find any subscriptions for #{repo} #{event} events"

    for i, listener in listeners
      if _.isEqual(listener,msg.message.user)
        removed = listeners.splice(i,1)

    if ! removed
      return msg.send "I don't think you're subscribed to #{repo} #{event} events"

    if listeners.length == 0
      data = QS.stringify {
        "hub.mode": 'unsubscribe',
        "hub.topic": "https://#{github_url}/#{repo}/events/#{event}.json"
        "hub.callback": "#{process.env.HUBOT_URL}/hubot/gh_hooks/#{github_url}/#{event}"
      }

      msg.http("https://api.#{github_url}")
        .path('/hub')
        .auth(process.env.HUBOT_GITHUB_USER,process.env.HUBOT_GITHUB_PASSWORD)
        .post(data) (err,res,body) ->
          switch res.statusCode
            when 200
              delete events[event]
              msg.send "Removed my subscription to #{repo} #{event} events"
            else
              msg.send "Failed to unsubscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"

  # Public: Subsribe to an event type for a repository
  robot.respond /gh_hooks subscribe (.*) (.*)? (.*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    # Convenience accessors with initialization
    repos = robot.brain.data.gh_hooks[github_url] || = {}
    events = repos[repo] ||= {}
    listeners = events[event] ||= []

    add_listener = ->
      if ! listeners.some((elem) ->
        _.isEqual(elem,msg.message.user)
      )
        listeners.push msg.message.user

      msg.send "Subscribed to #{repo} #{event} events on #{github_url}"

    # Check to see if we have any subscriptions to this event type for the repo
    if listeners.length == 0
      data = QS.stringify {
        "hub.mode": 'subscribe',
        "hub.topic": "https://#{github_url}/#{repo}/events/#{event}.json"
        "hub.callback": "#{process.env.HUBOT_URL}/hubot/gh_hooks/#{github_url}/#{event}"
      }

      msg.http("https://api.#{github_url}")
        .path('/hub')
        .header('Authorization', 'Basic ' + new Buffer("#{process.env.HUBOT_GITHUB_USER}:#{process.env.HUBOT_GITHUB_PASSWORD}").toString('base64'))
        #.auth(process.env.HUBOT_GITHUB_USER,process.env.HUBOT_GITHUB_PASSWORD)
        .post(data) (err,res,body) ->
          switch res.statusCode
            when 204
              add_listener()
            else
              robot.logger.debug "Failed to subscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"
              msg.send "Failed to subscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"
    else
      msg.send "I'm already listening to these. Adding you."
      add_listener()


  robot.brain.on 'loaded', =>
    robot.brain.data.gh_hooks ||= {}


  robot.router.post '/hubot/gh_hooks/:github/:event', (req, res) ->
    req.body = req.body || {}

    return res.end "ok" unless req.body.repository # Not something we care about. Who does this?

    event = req.params.event
    repo_name =  (req.body.repository.owner.login || req.body.repository.owner.name) + "/" + req.body.repository.name


    robot.logger.debug "Finding event #{event} in views"
    if views[event]
      context = _.extend req.body,
        repo: req.body.repository
        repo_name: repo_name
        github_url: req.params.github
        branch: if req.body.ref
            req.body.ref.replace(/^refs\/heads\//,'')
          else
            undefined
      template = Handlebars.compile(views[event])
      message = template(context)
    else
      robot.logger.debug "Template not found, pushing out lameness"
      message = {}
      message[event] = req.body
      message = JSON.stringify message

    listeners = robot.brain.data.gh_hooks[req.params.github]?[repo_name][event] || []
    robot.logger.debug "Body:"
    robot.logger.debug JSON.stringify req.body

    robot.logger.debug "Sending message:"
    robot.logger.debug message

    for listener in listeners when listener
      robot.send listener, message.split("\n")...

    res.end "ok"
