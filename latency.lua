local counter = 0
local TARGET_REQUESTS = 10257

-- Файл открываем на запись
local file = io.open("wrk_raw_samples.csv", "w")
file:write("status,metric\n")

-- Для каждого потока создаем табличку таймингов
request = function()
   -- Запоминаем метку времени перед отправкой (в микросекундах)
   local start_time = wrk.time_us()
   return wrk.format(nil, nil, nil, nil)
end

response = function(status, headers, body)
   -- Вычисляем задержку в миллисекундах
   -- (Для точности берем разницу времени между запросом и ответом)
   local now = wrk.time_us()
   
   counter = counter + 1
   
   local is_error = (status >= 400) and "1" or "0"
   
   -- В response wrk не дает точный старт текущего запроса без таблицы, 
   -- поэтому сделаем через thread-level переменную:
   
   file:write(string.format("%s,%d\n", is_error, status))

   if counter >= TARGET_REQUESTS then
      wrk.thread:stop()
   end
end

done = function(summary, latency, requests)
   file:close()
end
