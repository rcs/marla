# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set
#
# Environment Variables:
#
# PREFIX_URL  : The place where this hubot is mounted (ex "http//hubot.example.com"
# GITHUB_USER : The github user to use for the API
# GITHUB_USER : The password to use for the API

QS = require 'querystring'

module.exports = (robot) ->
  _ = require('underscore')

  room_or_user = (user) ->


  robot.respond /gh_hooks subscribe (.*) (.*)? (.*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    msg.send "Subscribing to #{repo} #{event} events on #{github_url}"

    add_listener = ->
      if ! robot.brain.data.gh_hooks[github_url][repo][event].some((elem) ->
        _.isEqual(elem,msg.user)
      )
        subscribed.push msg.user

      msg.send "Subscribed to #{repo} #{event} events on #{github_url}"

    subscribed = target[repo] ||= []

    # Check to see if we have any subscriptions to this event type for the repo
    if robot.brain.data.gh_hooks[github_url]?[repo]?[event] == undefined
      data = QS.stringify {
        "hub.mode": 'subscribe',
        "hub.topic": "https://#{github_url}/#{repo}/events/#{event}.json"
        "hub.callback": "#{HUBOT_URL}/hubot/gh_hooks/#{github_url}/#{event}"
      }

      msg.http("https://api.#{github_url}")
        .path('/hub')
        .auth(HUBOT_GITHUB_USERNAME,HUBOT_GITHUB_PASSWORD)
        .post(data) (err,res,body) ->
          switch res.statusCode
            when 200
              add_listener()
            else
              msg.send "Failed to subscribe to #{repo} #{event} events on #{github_url}: #{body}"
    else
      add_listener()


  robot.brain.on 'loaded', =>
    robot.brain.data.gh-hooks = {}


  robot.router.post '/hubot/gh-hooks/:github/push', (req, res) ->
    req.body = req.body || {}

    robot.logger.debug JSON.stringify(req.body)

    if req.body.pusher

      pusher = req.body.pusher
      head = req.body.head_commit
      repo = req.body.repository
      first = req.body.commits[0]

      branch = req.body.ref.replace(/^refs\/head\//,'')

      listeners = robot.brain.gh_hooks[req.params.github]?[repo]['push'] || []

      for listener in listeners
        robot.send listener, "#{pusher.name} pushed to #{branch} at #{repo.owner.name}/#{repo.name} #{req.body.compare}"
        for commit in req.body.commits
          robot.send listener, "#{commit.author.username}: #{commit.id.substring(0,7)} #{commit.message}"

      robot.logger.debug "#{pusher.name} pushed to #{branch} at #{repo.owner.name}/#{repo.name} #{req.body.compare}"
      robot.logger.debug "#{head.author.username}: #{head.id.substring(0,7)} #{head.message}"

      if req.body.commits.length > 1
        robot.logger.debug "#{req.body.commits.length - 1} more commits #{payload.compare}"


    res.end "ok"
