# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set
# requires github-credentials



module.exports = (robot) ->
  robot.brain.on 'loaded', =>
    robot.brain.data.gh-hooks = {}


  robot.router.post '/hubot/gh-hooks/push', (req, res) ->
    req.body = req.body || {}

    robot.logger.debug req.body

    if req.body['payload']
      payload = JSON.parse(req.body['payload'])

      pusher = payload.pusher
      head = payload.head_commit
      repo = payload.repository
      first = payload.commits[0]

      branch = first.ref.replace(/^refs\/head\//,'')

      msg = []
      msg.push "#{pusher.name} pushed to #{branch} at #{repo.owner.name}/#{repo.name} #{payload.compare}"
      msg.push "#{head.author.username}: #{head.id.substring(0,7)} #{head.message} #{head.url}"

      if payload.commits.length > 1
        msg.push "#{payload.commits.length -1} more commits #{payload.compare}"

      for s in msg
        robot.logger.debug s

    res.end "ok"

  robot.respond /gh-hooks add (.*) (push)/, (msg) ->


    robot.brain.data.gh-hooks
    for k of msg
      robot.logger.debug "#{k}: #{msg[k]}"

    robot.logger.debug "Message:"
    for k of msg.message
      robot.logger.debug "\t#{k}: #{msg.message[k]}"
    robot.logger.debug "User:"
    for k of msg.message.user
      robot.logger.debug "\t#{k}: #{msg.message.user[k]}"
    msg.reply "Subscribing to #{msg.match[2]} events for #{msg.match[1]}"

