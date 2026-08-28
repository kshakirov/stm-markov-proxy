function setup(thread)
    -- Передаем уникальный числовой ID потока в его изолированный контекст
    thread:set("thread_id", thread.id)
end

function init(args)
    -- Получаем ID текущего потока из глобального пространства контекста
    local id = thread_id
    
    local filename = string.format("requests_thread_%s.csv", id)
    local file = io.open(filename, "w")
    if not file then
        return -1
    end
    
    -- Заголовок: 1 - успех, 0 - ошибка. Задержка в микросекундах.
    file:write("success,latency_us\n")
    thread_file = file
end

function response(status, headers, body)
    -- Успех — это статусы 2xx и 3xx
    local success = (status >= 200 and status < 400) and 1 or 0
    local latency = wrk.latency
    
    thread_file:write(string.format("%d,%d\n", success, latency))
end

