# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set
# requires github-credentials



module.exports = (robot) ->
  robot.brain.on 'loaded', =>
    robot.brain.data.gh-hooks = {}


  robot.router.post '/hubot/gh-hooks/push', (req, res) ->
    req.body = req.body || {}

    if req.body.pusher

      pusher = req.body.pusher
      head = req.body.head_commit
      repo = req.body.repository
      first = req.body.commits[0]

      branch = first.ref.replace(/^refs\/head\//,'')

      robot.logger.debug "#{pusher.name} pushed to #{branch} at #{repo.owner.name}/#{repo.name} #{req.body.compare}"
      robot.logger.debug "#{head.author.username}: #{head.id.substring(0,7)} #{head.message} #{head.url}"

      if req.body.commits.length > 1
        robot.logger.debug "#{req.body.commits.length -1} more commits #{payload.compare}"


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

