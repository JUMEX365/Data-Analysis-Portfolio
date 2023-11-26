--Тестовое задание от ведущего продуктового аналитика ВКонтакте для бизнеса (VK Реклама)--
--done by JUMEX365--




/*Задача 1:
 
Выведите все уникальные комбинации процессор - память - графика из таблицы necessary_hardware и посчитайте количество каждой уникальной комбинации*/

SELECT DISTINCT processor, memory, graphics
FROM twitter.necessary_hardware;

/* Решение, допиленное до ума (дополнительно): 
оконной функцией посчитано кол-во ТАКИХ значений уникальных комбинаций процессора, оперативки и видиокарты*/

SELECT DISTINCT  processor, memory, graphics,
	COUNT(*) OVER(PARTITION BY processor, memory, graphics) AS N_of_this_unq_comb
FROM twitter.necessary_hardware
ORDER BY N_of_this_unq_comb DESC;




/*Задача 2:

Выведите список игр из таблицы games, которые:
1) стоят больше 300
2) или у которых 3 и более жанра и релиз произошел до 2018 года 
Результат должен содержать поля id, name, price, release_date, genres, description*/

SELECT  id, name, price, release_date, genres, description, 
FROM twitter.games
WHERE (price > 300 
OR (LENGTH(splitByChar(',', genres)) >= 3 AND release_date < '2018-01-01 00:00:00'));




/*Задача 3:

Выведите список игр из таблицы games, которые хотя бы раз получили оценку больше или равную 95 от топ-критиков. 
Результат должен содержать поля id, name, genres, description, price. 
Ответ не должен содержать соединений таблиц (нужно решить без использования JOIN)*/

SELECT  id, name, genres, description, price
FROM twitter.games
WHERE twitter.games.id IN (
	SELECT game_id 
	FROM twitter.open_critic
	WHERE (twitter.open_critic.top_critic = true AND twitter.open_critic.rating >= 95)
);



             
/*Задача 4:

Выведите статистику количества уникальных аккаунтов, количество твитов, среднее количество лайков, среднее количество ретвитов на каждую неделю по таблице tweets. 
Ответ должен содержать поля week, cnt_unique_accounts, cnt_unique_tweets, average_likes, average_retweets*/

SELECT 
	toRelativeWeekNum("timestamp") - 1999 AS week,
	COUNT(DISTINCT twitter_account_id) AS cnt_unique_accounts,
	COUNT(DISTINCT id) AS cnt_unique_tweets, 
	AVG(quantity_likes) AS average_likes,
	AVG(quantity_retweets) AS average_retweets
FROM twitter.tweets
GROUP BY week
ORDER BY week DESC;




/*Задача 5:
  
Для каждого разработчика (games.developer) выведите динамику медианной оценки (open_critic.rating) на каждый год. 
Временные промежутки считать по полю date в таблице open_critic. 
Результат должен содержать поля developer, year, median_rating*/

SELECT DISTINCT games.developer, 
	toYear(open_critic.date) AS year, 
	(median(open_critic.rating) OVER (PARTITION BY games.developer, year ORDER BY year)) AS median_rating 
FROM twitter.games
LEFT JOIN twitter.open_critic
ON twitter.games.id = twitter.open_critic.game_id 
WHERE games.developer <> '' AND year <> '1970' /*исключаем кривые значения, не влияет на расчет медианы (не обязательная строчка кода)*/
ORDER BY games.developer, open_critic.date DESC;




/*Задача 6:

Для каждой игры посчитайте какой процент твиттер аккаунтов этой игры имеет 1000 и более подписчиков. 
Результат должен содержать следующие поля 
- id, game, count_accounts_with_1000_or_more_followers_per_game, total_accounts_per_game, percent_accounts_with_1000_or_more_followers.
 В результате не должно быть NULL значений, такие значения нужно заменить на 0. Ответ не должен содержать CTE и Оконных Функций*/

/*Решение 1 (ОСНОВНОЕ), если twitter.games.name = game и надо джоинить таблицы games и twitter_accounts */
SELECT games.id, games.name AS game,
	COUNT (twitter_accounts.followers) AS total_accounts_per_game,
	COUNT (CASE WHEN twitter_accounts.followers >= 1000 THEN 1 ELSE NULL END) AS count_accounts_with_1000_or_more_followers_per_game, /*тут вместо 0 - NULL, т.к. почему то SQL сам рекодит 0 в 1*/
	100 * count_accounts_with_1000_or_more_followers_per_game / total_accounts_per_game AS percent_accounts_with_1000_or_more_followers
FROM twitter.games
LEFT JOIN twitter.twitter_accounts 
ON twitter.twitter_accounts.fk_game_id == twitter.games.id
GROUP BY games.id, game
ORDER BY percent_accounts_with_1000_or_more_followers;

/*Решение 2 (АЛЬТЕРАНТИВНОЕ), если twitter.twitter_accounts = game прямо из этой таблицы*/
SELECT id, name,
	COUNT (followers) AS total_accounts_per_game,
	COUNT (CASE WHEN followers >= 1000 THEN 1 ELSE null END) AS count_accounts_with_1000_or_more_followers_per_game, /*тут вместо 0 - NULL, т.к. почему то SQL сам рекодит 0 в 1*/
	100 * count_accounts_with_1000_or_more_followers_per_game / total_accounts_per_game AS percent_accounts_with_1000_or_more_followers
FROM twitter.twitter_accounts
GROUP BY id, name
ORDER BY percent_accounts_with_1000_or_more_followers;




/*Задача 7:
 
Выведите список из топ-10 игр с наибольшим коэффициентом хайпа в твиттере. Коэффициент хайпа состоит из следующих показателей: 
1) количество твиттов, от аккаунтов связанных с игрой, написанных в ответ другим пользователям твиттера
2) количество реакций на твит (quantity_likes, quantity_quotes, quantity_retweets, quantity_replys)

Коэффициент хайпа считается по следующей формуле
12.6 * (суммарное количество твиттов, с ответами другим пользователям) + 5.2 * (суммарное количество ретвитов) +
+ 3.3 * (суммарное количество лайков) + 7 * (количество цитирований твита) + 4.2 * (суммарное количество ответов на твитты этого аккаунта)

Результат должен содержать поля id, name, price, release_date, hype_coefficient*/

SELECT DISTINCT games.id AS id, 
	games.name AS name, 
	games.price AS price, 
	games.release_date AS release_date,
		12.6*(count(CASE WHEN tweets.in_reply_to_user_id <> '' THEN 1 ELSE NULL END) OVER (PARTITION BY tweets.twitter_account_id) AS sum_of_ids) +
		5.2 *(sum(tweets.quantity_retweets) OVER (PARTITION BY games.id) AS sum_of_retweets) +
		3.3 *(sum(tweets.quantity_likes) OVER (PARTITION BY games.id) AS sum_of_likes) +
		7 *(sum(tweets.quantity_quotes) OVER (PARTITION BY games.id) AS sum_of_quotes) +
		4.2 *(sum(tweets.quantity_replys) OVER (PARTITION BY games.id) AS sum_of_replys) AS hype_coefficient
FROM twitter.games
LEFT JOIN twitter.twitter_accounts 
ON twitter.twitter_accounts.fk_game_id == twitter.games.id
LEFT JOIN twitter.tweets
ON twitter.tweets.twitter_account_id == twitter.twitter_accounts.id
ORDER BY hype_coefficient DESC
LIMIT 10;




/*Задача 8:

Посчитайте для каждой игры из таблицы games, какой процент лайков принёс каждый аккаунт, связанный с этой игрой, 
от общего количества лайков по этой игре. Считать для игр, вышедших в 2017 году. 
Учитывать только твиты, написанные в 2017 году. 
Аккаунты, связанные с игрой, но не писавшие твитов / не получившие лайков - тоже учитывать (их сумма лайков должна быть 0).
Считать без использования оконных функций. 
Результат должен состоять из колонок id, name, developer, release_date, twitter_account_id, twitter_account_name, 
sum_likes, total_likes, percent_of_total */

	WITH tab1 AS (SELECT sum(tweets.quantity_likes) AS sum_likes, twitter.twitter_accounts.id AS tw_ac_id
	FROM twitter.tweets
	LEFT JOIN twitter.twitter_accounts
	ON twitter.twitter_accounts.id=twitter.tweets.twitter_account_id
	LEFT JOIN twitter.games
	ON twitter.twitter_accounts.fk_game_id=twitter.games.id
	WHERE toYear(twitter.tweets.timestamp) = 2017 AND toYear(twitter.games.release_date) = 2017
	GROUP by tw_ac_id),
		tab2 AS (SELECT sum(tweets.quantity_likes) AS total_likes, twitter.games.id AS gm_id
		FROM twitter.tweets
		LEFT JOIN twitter.twitter_accounts
		ON twitter.twitter_accounts.id=twitter.tweets.twitter_account_id
		LEFT JOIN twitter.games
		ON twitter.twitter_accounts.fk_game_id=twitter.games.id
		WHERE toYear(twitter.tweets.timestamp) = 2017 AND toYear(twitter.games.release_date) = 2017
		GROUP by gm_id)
Select 
	games.id AS id, 
	games.name AS name, 
	games.developer AS developer, 
	games.release_date AS release_date, 
		twitter_accounts.id AS twitter_account_id, 
		twitter_accounts.name AS twitter_account_name,
			tab1.sum_likes AS sum_likes, 
				tab2.total_likes AS total_likes,
					sum_likes / total_likes * 100 AS percent_of_total
From twitter.games 
	left join twitter.twitter_accounts
	On twitter.games.id=twitter.twitter_accounts.fk_game_id
		right join tab1
		on tw_ac_id == twitter.twitter_accounts.id
			right join tab2
			on gm_id == twitter.games.id;

		

		
/*Задача 9:

Для каждого уникального жанра игр посчитать количество игр в магазине, 
у которых рейтинг от топовых критиков в среднем больше либо равен 85. 
Вывести топ-10 жанров. 
Результат должен состоять из столбцов genre, games_count
Подсказка: столбец с жанрами нужно построчно разбить на уникальные жанры*/

	WITH tab5 AS(
			WITH tab4 AS (SELECT DISTINCT  id, name, avg(rating) OVER(PARTITION BY id) as avg_rating, splitByChar(',', genres) AS splt
			FROM twitter.games
			LEFT JOIN twitter.open_critic
			ON twitter.games.id=twitter.open_critic.game_id
			WHERE twitter.open_critic.top_critic = true)
		SELECT *, 
		FROM tab4
		ARRAY JOIN splt
		WHERE avg_rating >=85)
Select DISTINCT splt as genre, COUNT(genre) OVER(PARTITION BY genre) AS games_count
From tab5
WHERE genre <> '' -- Удаляем строку, если хотим вывести игры "без жанра"
ORDER BY games_count DESC
LIMIT 10;




/*Задача 10:

Для каждой игры, вышедшей в ноябре 2018 года, 
посчитайте количество уникальных профилей в каждой социально сети (таблица social_networks). 
Каждой социальной сети задайте правильно название (например, linkFacebook -> Facebook.com). 
Нельзя использовать CASE WHEN и multiIf. 
Результат должен содержать колонки id, name, social_network, count_social_network_accounts*/

	WITH tab7 AS(
		WITH tab6 AS(	
			SELECT games.id, games.name, social_networks.url 
			FROM twitter.games
			LEFT JOIN twitter.social_networks
			ON twitter.social_networks.fk_game_id = twitter.games.id
			WHERE release_date BETWEEN '2018-11-01 00:00:00' AND '2018-11-30 23:59:59')
				SELECT id, name, 
					regexp_replace(tab6.url, '^https?://(www.)?([a-zA-Z\\.]+\\.[a-zA-Z]{2,6})(/.*)?$', '\\2')  AS social_network,
					count(social_network) OVER (PARTITION BY id, social_network) AS count_social_network_accounts
				FROM tab6)
SELECT id, name,  
	CONCAT(UPPER(SUBSTRING(social_network, 1, 1)), LOWER(SUBSTRING(social_network, 2))) AS social_network,
	count_social_network_accounts
FROM tab7;




/*Задача 11:

По таблице open_critic для каждого уникального ревьювера (комбинация стобцов author + company) 
и каждого их ревью достройте следующие столбцы - длина ревью (количество символов), 
средняя длина 3-х предыдущих ревью этого автора, средняя длина 3-х предыдущих ревью по этой игре. 
Результат должен содержать следующие колокни: company, author, date, game_name, comment, 
current_comment_length, previous_3_comment_average_length_this_author, previous_3_comment_average_length_this_game */

 
-- Тут старался удалить все дубликаты комментариев, т.к. посчитал, что так будет правильнее.

				WITH tab9 AS (
	                    WITH tab8 AS(
	                          SELECT DISTINCT(author AS au, company AS co, comment AS re), first_value(id) AS id
	                          FROM twitter.open_critic
	                          group by author, company, comment                   
	                          )
	                    SELECT DISTINCT id, company, author, rating, comment, top_critic, game_id, 
	                    date, LENGTH(comment) AS current_comment_length
	                    FROM twitter.open_critic
	                    INNER JOIN tab8 
	                    ON open_critic.id = tab8.id
	                    WHERE open_critic.id = tab8.id
	             ),
		tab10 AS (
			SELECT DISTINCT *, 
            	avg(current_comment_length) OVER (PARTITION BY (company, author) ORDER BY date ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS previous_3_comment_average_length_this_author,
            	avg(current_comment_length) OVER (PARTITION BY game_id ORDER BY date ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS previous_3_comment_average_length_this_game
            FROM tab9
         )
SELECT tab9.company AS company, tab9.author AS author, tab9.date AS date, 
  games.name AS game_name,
   tab9.comment AS comment, tab9.current_comment_length AS current_comment_length,
   tab10.previous_3_comment_average_length_this_author AS previous_3_comment_average_length_this_author,
  tab10.previous_3_comment_average_length_this_game AS previous_3_comment_average_length_this_game
FROM tab9
LEFT JOIN tab10
ON tab9.id = tab10.id
LEFT JOIN twitter.games
ON tab9.tab9.game_id = twitter.games.id
ORDER BY date DESC;




/*Задача 12:

Найти топ-10 пользователей по таблице tweets, написавших наибольшее количество твитов в 2016 году.
Вывести всех их твиты. 
Для каждого твита посчитайте «бегущую сумму» лайков, реплаев, ретвитов, цитат 
отдельными столбцами от самого раннего твита (за 2016 год) до самого позднего за 2016 год 
(«бегущая сумма» - сумма всех значений от самого первого до нынешнего значения включительно). 
Результат должен выводить столбцы 
twitter_account_id, text, quantity_likes, running_sum_likes, quantity_quotes, 
running_sum_quotes, quantity_retweets, running_sum_retweets, quantity_replys, running_sum_replys */

			WITH tab11 AS (
				SELECT DISTINCT  twitter_account_id as list_top_id, COUNT (id) OVER(PARTITION BY twitter_account_id) AS total_tweets
				FROM twitter.tweets
				WHERE toYear(twitter.tweets.timestamp) = 2016
				ORDER BY total_tweets DESC
				LIMIT 10
			),
		tab12 AS (
		SELECT * 
		FROM twitter.tweets
		WHERE toYear(twitter.tweets.timestamp) = 2016
		)
SELECT twitter_account_id, text,
quantity_likes,
sum(quantity_likes) OVER (PARTITION BY twitter_account_id ORDER BY timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND 0 PRECEDING) AS running_sum_likes,
 quantity_quotes,
 sum(quantity_quotes) OVER (PARTITION BY twitter_account_id ORDER BY timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND 0 PRECEDING) AS running_sum_quotes,
  quantity_retweets,
  sum(quantity_likes) OVER (PARTITION BY twitter_account_id ORDER BY timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND 0 PRECEDING) AS running_sum_retweets,
   quantity_replys,
   sum(quantity_replys) OVER (PARTITION BY twitter_account_id ORDER BY timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND 0 PRECEDING) AS running_sum_replys
FROM tab12
RIGHT JOIN tab11
ON tab11.list_top_id = tab12.twitter_account_id
ORDER BY twitter_account_id, timestamp; 


 

/*Задача 13 (В СЛЕПУЮ, БЕЗ БД):

У вас есть таблицы Orders (partition_date, order_id, user_id, price) 
и таблица Users (user_id, email, age, gender, install_date). 

Для возрастных групп до 20, 21-40, 41+ выведите средний чек, максимальный и минимальный чек на каждый месяц*/

SELECT DISTINCT (CASE WHEN Users.age =< 20 THEN 'under_20' -- 20 лет включаем в группу "до 20"
   WHEN user.age BETWEEN 21 AND 40 THEN '21-40'
   ELSE '40_plus' 
   END) AS age_groups,
 toStartOfMonth(Orders.partition_date) AS month_n,
	avg(Orders.price) OVER (PARTITION BY age_groups, months_n) AS mean_check,
	max(Orders.price) OVER (PARTITION BY age_groups, months_n) AS max_check,
	min(Orders.price) OVER (PARTITION BY age_groups, months_n) AS min_check,
FROM DB.Users
LEFT JOIN DB.Orders
ON DB.Users.user_id = DB.Orders.user_id
ORDER BY age_groups, month_n;




/*Задача 14 (В СЛЕПУЮ, БЕЗ БД):

У вас есть таблица stock_rates (datetime, currency_pair, exchange_rate). 
В таблицу каждую минуту записываются данные об обменном курсе валютных пар. 
Выведите для каждой валютной пары курс обмена на минимальный момент времени на каждый день (самое первое значение курса каждый день)*/

WITH cur_exch_rate AS (
	SELECT DISTINCT datetime, currency_pair, exchange_rate, RANK() OVER (PARTITION BY currency_pair, toDate(datetime) ORDER BY datetime ASC) AS rnk
	FROM DB.stock_rates)
SELECT datetime, currency_pair, exchange_rate
FROM cur_exch_rate
WHERE rnk=1;




/*Задача 15 (В СЛЕПУЮ, БЕЗ БД):

У вас есть таблица с зарплатами сотрудников Employee (id, salary). Выведите 2-ю самую большую зарплату*/

WITH CTE_TAB AS ( 
	SELECT id, salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
	FROM DB.Employee
	)
SELECT salary 
FROM CTE_TAB
WHERE rnk = 2
LIMIT 1;




/*Задача 16 (В СЛЕПУЮ, БЕЗ БД):

Написать скрипт, который будет ежедневно добавлять из таблицы all_events в таблицу streams свежие данные. 
Таблица streams содержит данные об уникальных прошедших стримах: 
т.е каждая строка - это уникальная трансляция одного уникального стримера. 
Таблица streams состоит из следующих колонок partition_date, stream_start_timestamp, stream_end_timestamp, stream_id, streamer_id*/


/*Решение:
Сам запрос будет добавлять данные по стримам, которые завершились вчера, в таблицу streams.
Запуск запроса будет проводится каждый день в 05:00 (5 утра) автоматически.
Это можно реализовать через:
1) "Планировщик задач", он же "Task Sсheduler", доступный в DBeaver Enterprise Edition
2) Терминал WINDOWS и Bash Script. */

INSERT INTO streams (stream_id, streamer_id, stream_start_timestamp, stream_end_timestamp, stream_start_timestamp, partition_date)
SELECT all_events.stream_id AS stream_id,
	all_events.user_id AS streamer_id,
	all_events.timestamp AS stream_start_timestamp,
	copy.timestamp AS stream_end_timestamp,
	all_events.partition_date AS partition_date 
FROM all_events
INNER JOIN all_events copy
	ON all_events.user_id = copy.user_id
		AND all_events.stream_id = copy.stream_id 
		AND copy.event_name = 'stream_end' 
WHERE date_trunc('day', stream_end_timestamp) = date_trunc('day', (dateSub(now(), toDate('1 day')))) -- Т.е. не важно когда начался стрим, мы его добавляем в основную таблицу только заврешения.
	AND all_events.event_name = 'stream_start'; 




/*Задача 17 (В СЛЕПУЮ, БЕЗ БД):

Написать скрипт, который будет ежедневно добавлять из таблицы all_events в таблицу views свежие данные. 
Таблица views содержит данные об уникальных просмотрах стримов: т.е каждая строка - это уникальный просмотр одного уникального зрителя. 
Таблица views состоит из следующих колонок: partition_date, view_start_timestamp, view_end_timestamp, stream_id, viewer_id*/


/*Решение:
Сам запрос будет добавлять данные по просмотрам, которые завершились вчера, в таблицу views.
Запуск запроса будет проводится каждый день в 05:00 (5 утра) автоматически.
Это можно реализовать через:
1) "Планировщик задач", он же "Task Sсheduler", доступный в DBeaver Enterprise Edition
2) Терминал WINDOWS и Bash Script. */

INSERT INTO streams (stream_id, viewer_id, view_start_timestamp, view_end_timestamp, partition_date)
	WITH CTE_TAB_1 AS(
				SELECT all_events.stream_id AS stream_id,
				all_events.user_id AS viewer_id,
				all_events.timestamp AS view_start_timestamp,
				copy2.timestamp AS view_end_timestamp,
				all_events.partition_date AS partition_date -- partition_date (начала просмотра). Можно заменить на partition_date (конца просмотра) -> all_events.partition_date
			FROM all_events
			INNER JOIN all_events copy2
				ON all_events.user_id = copy2.user_id
					AND all_events.stream_id = copy2.stream_id 
					AND copy2.event_name = 'view_end'
			WHERE date_trunc('day', view_end_timestamp) = date_trunc('day', (dateSub(now(), toDate('1 day'))))
				AND all_events.event_name = 'view_start')
				), 
				-- Есть проблема: Зритель может в рамках дня посмотреть один и тот же стрим Х несколько раз, т.к в этом случае и stream_id и user_id 
				-- будут идентичными и при джойне получим массовое создание несуществующих просмотров. Например: 14:10-14:20, 14:10-18:00, 17:30-14:20, 17:30-18:00.
	CTE_TAB_2 AS (
	SELECT stream_id, viewer_id, view_start_timestamp, view_end_timestamp, partition_date, 
	ROW_NUMBER() OVER (PARTITION BY stream_id, viewer_id, view_start_timestamp  ORDER BY view_end_timestamp ASC) AS rn
	FROM CTE_TAB_1
	WHERE view_start_timestamp < view_end_timestamp
	)
SELECT stream_id, viewer_id, view_start_timestamp, view_end_timestamp, partition_date
FROM CTE_TAB_2
WHERE rn = 1; -- Это дополнение к скрипту решает проблему несуществующих просмотров.









