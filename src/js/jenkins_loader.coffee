'use strict'

JenkinsLoader = (url) ->
    @_url = url
    @_jobs = []
    @_cacheExpirationPeriod = 3600 * 1000
    @_jobsRequest = '/api/json?tree=jobs[name]'
    @_buildsRequest = '/api/json?tree=builds[number,result,timestamp,artifacts[relativePath],changeSet[items[commitId,msg]]]'
    return

JenkinsLoader::loadJobs = (viewName, callback) ->
    self = this
    viewUrl = self._url + '/view/' + viewName
    jobsDataTag = viewUrl + '_JobsData'
    cacheLastUpdateTag = viewUrl + '_JobsLastUpdate'

    wrappedCallback = (jobs) ->
        self._jobs = jobs
        callback jobs
        return

    chrome.storage.local.get [
        cacheLastUpdateTag
        jobsDataTag
    ], (result) ->
        jobsDataTimestamp = $.now()
        cachedJobsData = result[jobsDataTag]
        cachedJobsLastUpdate = result[cacheLastUpdateTag]

        cachedCallback = ->
            if cachedJobsData
                GUI.log i18n.getMessage('buildServerUsingCached', [ 'jobs' ])
            wrappedCallback if cachedJobsData then cachedJobsData else []
            return

        if !cachedJobsData or !cachedJobsLastUpdate or jobsDataTimestamp - cachedJobsLastUpdate > self._cacheExpirationPeriod
            url = ''.concat(viewUrl).concat(self._jobsRequest)
            $.get(url, (jobsInfo) ->
                GUI.log i18n.getMessage('buildServerLoaded', [ 'jobs' ])
                # remove OrniFlight prefix, rename OrniFlight job to Development
                jobs = jobsInfo.jobs.map((job) ->
                    {
                        title: job.name.replace('OrniFlight ', '').replace('OrniFlight', 'Development')
                        name: job.name
                    }
                )
                # cache loaded info
                object = {}
                object[jobsDataTag] = jobs
                object[cacheLastUpdateTag] = $.now()
                chrome.storage.local.set object
                wrappedCallback jobs
                return
            ).fail (xhr) ->
                GUI.log i18n.getMessage('buildServerLoadFailed', [
                    'jobs'
                    'HTTP '.concat(xhr.status)
                ])
                cachedCallback()
                return
        else
            cachedCallback()
        return
    return

JenkinsLoader::loadBuilds = (jobName, callback) ->
    self = this
    jobUrl = ''.concat(self._url, '/job/').concat(jobName)
    buildsDataTag = ''.concat(jobUrl, 'BuildsData')
    cacheLastUpdateTag = ''.concat(jobUrl, 'BuildsLastUpdate')
    chrome.storage.local.get [
        cacheLastUpdateTag
        buildsDataTag
    ], (result) ->
        buildsDataTimestamp = $.now()
        cachedBuildsData = result[buildsDataTag]
        cachedBuildsLastUpdate = result[cacheLastUpdateTag]

        cachedCallback = ->
            if cachedBuildsData
                GUI.log i18n.getMessage('buildServerUsingCached', [ jobName ])
            self._parseBuilds jobUrl, jobName, (if cachedBuildsData then cachedBuildsData else []), callback
            return

        if !cachedBuildsData or !cachedBuildsLastUpdate or buildsDataTimestamp - cachedBuildsLastUpdate > self._cacheExpirationPeriod
            url = ''.concat(jobUrl).concat(self._buildsRequest)
            $.get(url, (buildsInfo) ->
                GUI.log i18n.getMessage('buildServerLoaded', [ jobName ])
                # filter successful builds
                builds = buildsInfo.builds.filter((build) ->
                    build.result == 'SUCCESS'
                ).map((build) ->
                    {
                        number: build.number
                        artifacts: build.artifacts.map((artifact) ->
                            artifact.relativePath
                        )
                        changes: build.changeSet.items.map((item) ->
                            '* ' + item.msg
                        ).join('<br>\n')
                        timestamp: build.timestamp
                    }
                )
                # cache loaded info
                object = {}
                object[buildsDataTag] = builds
                object[cacheLastUpdateTag] = $.now()
                chrome.storage.local.set object
                self._parseBuilds jobUrl, jobName, builds, callback
                return
            ).fail (xhr) ->
                GUI.log i18n.getMessage('buildServerLoadFailed', [
                    jobName
                    'HTTP '.concat(xhr.status)
                ])
                cachedCallback()
                return
        else
            cachedCallback()
        return
    return

JenkinsLoader::_parseBuilds = (jobUrl, jobName, builds, callback) ->
    # convert from `build -> targets` to `target -> builds` mapping
    targetBuilds = {}
    targetFromFilenameExpression = /orniflight_([\d.]+)?_?(\w+)(\-.*)?\.(.*)/
    builds.forEach (build) ->
        build.artifacts.forEach (relativePath) ->
            match = targetFromFilenameExpression.exec(relativePath)
            if !match
                return
            version = match[1]
            target = match[2]
            date = new Date(build.timestamp)
            formattedDate = ('0' + date.getDate()).slice(-2) + '-' + ('0' + date.getMonth() + 1).slice(-2) + '-' + date.getFullYear() + ' ' + ('0' + date.getHours()).slice(-2) + ':' + ('0' + date.getMinutes()).slice(-2)
            descriptor = 
                'releaseUrl': jobUrl + '/' + build.number
                'name': jobName + ' #' + build.number
                'version': version + ' #' + build.number
                'url': jobUrl + '/' + build.number + '/artifact/' + relativePath
                'file': relativePath.split('/').slice(-1)[0]
                'target': target
                'date': formattedDate
                'notes': build.changes
            if targetBuilds[target]
                targetBuilds[target].push descriptor
            else
                targetBuilds[target] = [ descriptor ]
            return
        return
    callback targetBuilds
    return