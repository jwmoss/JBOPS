$TFRAME = 1.577e+7  # ~ 6 months in seconds
#$TODAY = Get-Date

# ## EDIT THESE SETTINGS ##
$TAUTULLI_APIKEY = ''  # Your Tautulli API key
$TAUTULLI_URL = 'http://192.168.1.254:8181'  # Your Tautulli URL
$LIBRARY_NAMES = @('Movies', 'TV Shows')  # Name of libraries you want to check.
#$SUBJECT_TEXT = "Tautulli Notification"
#$NOTIFIER_ID = 12  # The email notification agent ID for Tautulli

#$show_lst = @()
#$notify_lst = @()

#libraries = [lib for lib in get_libraries_table()]

function Get-LibraryTable {
    [CmdletBinding()]
    param (
        [String]
        $TAUTULLI_APIKEY,

        [String]
        $TAUTULLI_URL,

        [String[]]
        $LIBRARY_NAMES
    )
  
    $r = Invoke-RestMethod -Uri ($TAUTULLI_URL + "/api/v2") -Body @{
        apikey = $TAUTULLI_APIKEY
        cmd    = "get_libraries_table"
    }
    
    [Hashtable]$d = @{}

    $r.response.data.data | Where-object {
        $PSItem.section_name -in $LIBRARY_NAMES
    } | ForEach-Object {
        $d.Add([int]$_.section_id,$_)
    }
    $d
}

function Get-LibraryMediaInfo {
    [CmdletBinding()]
    param (
        [String]
        $TAUTULLI_APIKEY,

        [String]
        $TAUTULLI_URL,

        [Int32]
        $SECTION_ID
    )
    
    $body = @{
        apikey     = $TAUTULLI_APIKEY
        section_id = $SECTION_ID
        cmd        = "get_library_media_info"
        length     = 999
    }

    $r = Invoke-RestMethod -Uri ($TAUTULLI_URL + "/api/v2") -Body $body

    $r.response.data.data

    <#
        try:
    r = requests.get(TAUTULLI_URL.rstrip('/') + '/api/v2', params=payload)
    response = r.json()
    res_data = response['response']['data']['data']
    return [LIBINFO(data = d) for d in res_data if d['play_count'] is None and (TODAY - int(d['added_at'])) > TFRAME]

    except Exception as e:
    sys.stderr.write("Tautulli API 'get_library_media_info' request failed: {0}.".format(e))
    #>

}

function Send-Notification {
    [CmdletBinding()]
    param (
        [String]
        $TAUTULLI_APIKEY,

        [String]
        $TAUTULLI_URL,

        [Int32]
        $SECTION_ID,

        [String]
        $Subject,

        [String]
        $Body
    )
    
    $RestBody = @{
        apikey = $TAUTULLI_APIKEY
        cmd = "notify"
        notifier_id = "3" ## Email
        subject = $Subject
        body = $Body
    }

    $r = Invoke-RestMethod -Uri ($TAUTULLI_URL + "/api/v2") -Body $RestBody -Method POST

    $r.response
}

$config = @{
    TAUTULLI_URL    = $TAUTULLI_URL
    TAUTULLI_APIKEY = $TAUTULLI_APIKEY
}

$libraries = Get-LibraryTable -TAUTULLI_APIKEY $TAUTULLI_APIKEY -TAUTULLI_URL $TAUTULLI_URL -LIBRARY_NAMES $LIBRARY_NAMES

$library_media_info = $libraries.Keys.ForEach({
    Get-LibraryMediaInfo @config -SECTION_ID $_
})

$library_media_info | ForEach-Object {
    $day_added = $origin.AddSeconds($_.added_at)
    if ($day_added -lt (Get-Date).AddMonths(-6) -and ($_.last_played -eq $null)) {
        $day_added_clean = ([DateTime]$day_added).ToString('yyyy-MM-dd')
        [PSCustomObject]@{
            Title = $_.title
            Date = $day_added_clean
            LastPlayed = $_.last_played
        }
    }
}

($final | Sort-Object -Property date -Descending)