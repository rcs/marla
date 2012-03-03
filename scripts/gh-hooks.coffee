# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set
#
# Environment Variables:
#
# PREFIX_URL  : The place where this hubot is mounted (ex "http//hubot.example.com"
# GITHUB_USER : The github user to use for the API
# GITHUB_USER : The password to use for the API

QS = require 'querystring'
Handlebars = require 'handlebars'

EVENTS = ['push','issues']

views =
  push:
    """
      [{{repo_name}}] {{pusher.name}} pushed to {{branch}} {{compare}}"
      {{#each commits}}  {{author.username}}: {{id}} {{message}}
      {{/each}}
    """
  issues:
    """
      {{sender.login}} {{action}} issue {{issue.number}} on {{repo_name}} {{issue.html_url}}
    """

module.exports = (robot) ->
  _ = require('underscore')

  room_or_user = (user) ->


  robot.respond /gh_hooks subscriptions/, (msg) ->
    msg.send JSON.stringify robot.brain.data.gh_hooks

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
      msg.send "No listeners left, removing my subscription"
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

  robot.respond /gh_hooks subscribe (.*) (.*)? (.*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    msg.send "Subscribing to #{repo} #{event} events on #{github_url}"

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
      msg.send "No previous listeners... listening"
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
              msg.send "Adding you as a listener"
              add_listener()
            else
              msg.send "Failed to subscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"
    else
      msg.send "I'm already listening to these. Adding you"
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
        branch: if req.body.ref
            req.body.ref.replace(/^refs\/heads\//,'')
          else
            undefined
      template = Handlebars.compile(views[event])
      message = template(context)
    else
      robot.logger.debug "Template not found, pushing out lameness"
      robot.logger.debug JSON.stringify req.body
      message = JSON.stringify event: req.body

    listeners = robot.brain.data.gh_hooks[req.params.github]?[repo_name][event] || []
    robot.logger.debug "Body:"
    robot.logger.debug JSON.stringify req.body

    robot.logger.debug "Sending message:"
    robot.logger.debug message

    for listener in listeners when listener
      robot.send listener, message.split("\n")...

    res.end "ok"
