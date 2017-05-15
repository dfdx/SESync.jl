
using Requests
using Discourse

const BASE_URL = "https://api.stackexchange.com"
const LAST_CHECKED_FILE = expanduser("~/.sesync/last_checked")


function get_question(id::Integer)
    url = BASE_URL * "/2.2/questions/$id"
    query = Dict(:site => "stackoverflow",
                 :filter =>  "withbody")
    resp = get(url; query=query)
    return JSON.parse(String(resp.data))["items"][1]
end


function questions_from(fromdate::Int64)
    url = BASE_URL * "/2.2/questions"
    query = Dict(:page => 1,
                 :pagesize => 10,
                 :order => "desc",
                 :sort => "creation",
                 :tagged => "julia-lang",
                 :site => "stackoverflow",
                 :fromdate => fromdate)
    resp = get(url; query=query)
    return JSON.parse(String(resp.data))
end


function last_checked()
    if isfile(LAST_CHECKED_FILE)
        open(LAST_CHECKED_FILE) do f
            return parse(Int64, readstring(f))
        end
    else
        return round(Int64, time())
    end
end


function save_last_checked(ts::Int64)
    dirpath = dirname(LAST_CHECKED_FILE)
    if !isdir(dirpath)
        mkdir(dirpath)
    end
    open(LAST_CHECKED_FILE, "w") do f
        write(f, string(ts))
    end    
end


function question2topic(q::Dict)
    title = q["title"]
    body = q["body"] * "\n\n**Link:** " * q["link"]
    return Dict(:title => title, :content => body)
end


function main()
    ds = DiscourseClient(;base_url="https://discourse.julialang.org")
    ts = last_checked()
    next_ts = round(Int64, time())
    qs_meta = questions_from(ts)
    for q_meta in qs_meta["items"]
        q = get_question(q_meta["question_id"])
        topic = question2topic(q)
        create_topic(ds, topic[:title], topic[:content]; category="Usage")
    end
    save_last_checked(next_ts)
end
