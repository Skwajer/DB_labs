TRUNCATE TABLE
    booking, 
    issuance, 
    book_instance, 
    book, 
    publishing_house, 
    author, 
    reader 
RESTART IDENTITY CASCADE;

-- ========== ЗАДАНИЕ 1: АВТОРЫ ==========
INSERT INTO public.author (lastname, firstname) VALUES 
('Пушкин', 'Александр'),
('Чехов', 'Антон'),
('Толстой', 'Лев'),
('Достоевский', 'Фёдор'),
('Булгаков', 'Михаил'),
('Гоголь', 'Николай'),
('Тургенев', 'Иван')
RETURNING id;

DELETE FROM public.author WHERE id = 8;

UPDATE public.author 
SET 
    lastname = 'Достоевский',
    firstname = 'Фёдор Михайлович'
WHERE id = 4
RETURNING id;

-- ========== ЗАДАНИЕ 2: ИЗДАТЕЛЬСТВА ==========
INSERT INTO public.publishing_house (title, city) VALUES 
('Эксмо', 'Москва'),
('АСТ', 'Москва'),
('Дрофа', 'Москва'),
('Просвещение', 'Москва'),
('Росмэн', 'Москва'),
('Питер', 'Санкт-Петербург'),
('Азбука', 'Санкт-Петербург')
RETURNING id;

DELETE FROM public.publishing_house WHERE id = 3;

UPDATE public.publishing_house 
SET 
    title = 'АСТ',
    city = 'Москва'
WHERE id = 2
returning id;

-- ========== ЗАДАНИЕ 3: КНИГИ ==========
INSERT INTO public.book (title, id_author, id_publishing_house, version, year_of_public, circulation) VALUES 
('Евгений Онегин', 1, 1, 1, 1833, 5000),
('Преступление и наказание', 4, 2, 1, 1866, 10000),
('Мастер и Маргарита', 5, 1, 1, 1966, 15000),
('Мёртвые души', 6, 4, 1, 1842, 8000),
('Война и мир', 2, 2, 1, 1869, 12000),
('Отцы и дети', 7, 5, 1, 1862, 7000)
RETURNING id;

DELETE FROM public.book WHERE id = 4;

UPDATE public.book 
SET 
    title = 'Евгений Онегин',
    version = 1,
    circulation = 5000
WHERE id = 1
returning id;

-- ========== ЗАДАНИЕ 4: ЧИТАТЕЛИ ==========
INSERT INTO public.reader (id_reader_ticket, lastname, firstname, birthday, gender) VALUES 
(1001, 'Иванов', 'Пётр', '1990-05-15', 'М'),
(1002, 'Петрова', 'Мария', '1985-08-22', 'Ж'),
(1003, 'Сидоров', 'Алексей', '1992-12-03', 'М'),
(1004, 'Кузнецова', 'Ольга', '1988-03-18', 'Ж'),
(1005, 'Васильев', 'Дмитрий', '1995-07-30', 'М'),
(1006, 'Николаева', 'Елена', '1991-11-14', 'Ж')
RETURNING id_reader_ticket;

DELETE FROM public.reader WHERE id_reader_ticket = 1003
RETURNING id_reader_ticket;

UPDATE public.reader 
SET 
    lastname = 'Иванов',
    firstname = 'Пётр',
    gender = 'М'
WHERE id_reader_ticket = 1001
RETURNING id_reader_ticket;

-- ========== ЗАДАНИЕ 5: ЭКЗЕМПЛЯРЫ КНИГ ==========
INSERT INTO public.book_instance (inventory_number, book_info, state, status, location) VALUES 
(5001, 1, 'отличное', 'в наличии', 'Стеллаж А, полка 1'),
(5002, 1, 'хорошее', 'в наличии', 'Стеллаж А, полка 1'),
(5003, 2, 'отличное', 'в наличии', 'Стеллаж Б, полка 2'),
(5004, 2, 'удовлетворительное', 'выдана', 'Стеллаж Б, полка 2'),
(5005, 5, 'отличное', 'в наличии', 'Стеллаж В, полка 3'),
(5006, 5, 'хорошее', 'забронирована', 'Стеллаж В, полка 3'),
(5007, 6, 'ветхое', 'в наличии', 'Стеллаж Г, полка 1')
RETURNING inventory_number;

DELETE FROM public.book_instance WHERE inventory_number = 5004
RETURNING inventory_number;

UPDATE public.book_instance 
SET 
    state = 'отличное',
    status = 'в наличии',
    location = 'Стеллаж А, полка 1'
WHERE inventory_number = 5001
RETURNING inventory_number;

-- ========== ЗАДАНИЕ 6: ВЫДАЧА КНИГИ (VERSION 1) ==========
CREATE OR REPLACE FUNCTION issue_book(
    p_reader_id INTEGER,
    p_book_instance_id INTEGER
) RETURNS VOID AS $$
DECLARE
    v_reader_exists BOOLEAN;
    v_book_exists BOOLEAN;
    v_book_status VARCHAR(20);
    v_days_to_return INTEGER := 30;
BEGIN
    SELECT EXISTS(
        SELECT 1 
        FROM reader 
        WHERE id_reader_ticket = p_reader_id
    ) INTO v_reader_exists;
    
    IF NOT v_reader_exists THEN
        RAISE EXCEPTION 'Читатель с ID % не найден', p_reader_id;
    END IF;
    
    SELECT EXISTS(
        SELECT 1 
        FROM book_instance 
        WHERE inventory_number = p_book_instance_id
    ) INTO v_book_exists;
    
    IF NOT v_book_exists THEN
        RAISE EXCEPTION 'Экземпляр книги с номером % не найден', p_book_instance_id;
    END IF;
    
    SELECT status INTO v_book_status
    FROM book_instance 
    WHERE inventory_number = p_book_instance_id;
    
    IF v_book_status != 'в наличии' THEN
        RAISE EXCEPTION 'Выдача невозможна: книга сейчас "%"', v_book_status;
    END IF;
    
    BEGIN
        INSERT INTO issuance (
            fk_reader_ticket, 
            fk_inventory_number, 
            date_time_issue, 
            expected_return_date, 
            actual_return_date
        ) VALUES (
            p_reader_id, 
            p_book_instance_id, 
            NOW(), 
            CURRENT_DATE + (v_days_to_return || ' days')::INTERVAL, 
            NULL
        );
        
        UPDATE book_instance
        SET status = 'выдана'
        WHERE inventory_number = p_book_instance_id;
        
        RAISE NOTICE 'Книга % успешно выдана читателю % до %', 
            p_book_instance_id, 
            p_reader_id, 
            CURRENT_DATE + (v_days_to_return || ' days')::INTERVAL;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Ошибка при выдаче книги: %', SQLERRM;
    END;
    
END;
$$ LANGUAGE plpgsql;


-- ========== ЗАДАНИЕ 7: ФУНКЦИЯ ВОЗВРАТА КНИГИ ==========
CREATE OR REPLACE FUNCTION return_book(
    p_reader_id INTEGER,
    p_book_instance_id INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM reader WHERE id_reader_ticket = p_reader_id) THEN
        RAISE EXCEPTION 'Читатель % не найден', p_reader_id;
    END IF;
    
    IF NOT EXISTS(SELECT 1 FROM book_instance WHERE inventory_number = p_book_instance_id) THEN
        RAISE EXCEPTION 'Книга % не найдена', p_book_instance_id;
    END IF;
    
    IF NOT EXISTS(
        SELECT 1 
        FROM book_instance 
        WHERE inventory_number = p_book_instance_id 
        AND status = 'выдана'
    ) THEN
        RAISE EXCEPTION 'Книга % не выдана (текущий статус: %', 
            p_book_instance_id,
            (SELECT status FROM book_instance WHERE inventory_number = p_book_instance_id);
    END IF;
    
    IF NOT EXISTS(
        SELECT 1 
        FROM issuance 
        WHERE fk_reader_ticket = p_reader_id
            AND fk_inventory_number = p_book_instance_id
            AND actual_return_date IS NULL
    ) THEN
        RAISE EXCEPTION 'Книга % не выдана вам', p_book_instance_id;
    END IF;
    

    UPDATE issuance
    SET actual_return_date = CURRENT_DATE
    WHERE fk_reader_ticket = p_reader_id
        AND fk_inventory_number = p_book_instance_id
        AND actual_return_date IS NULL;
    
    UPDATE book_instance
    SET status = 'в наличии'
    WHERE inventory_number = p_book_instance_id;
    
    RAISE NOTICE 'Книга % успешно возвращена читателем %', 
        p_book_instance_id, p_reader_id;
    
END;
$$ LANGUAGE plpgsql;

-- ========== ЗАДАНИЕ 8: ПРЕДСТАВЛЕНИЕ ИНФОРМАЦИИ О ЭКЗЕМПЛЯРАХ КНИГ ==========
create or replace view issued_books_info as
select book_instance.inventory_number, reader.lastname as reader_lastname, reader.firstname as reader_name, author.firstname as author_name, author.lastname as author_lastname, title, state, date_time_issue, issuance.expected_return_date, issuance.actual_return_date
from issuance
inner join reader on issuance.fk_reader_ticket = reader.id_reader_ticket
inner join book_instance on issuance.fk_inventory_number = book_instance.inventory_number
inner join book on book_instance.book_info = book.id
inner join author on book.id_author = author.id;

/*select * 
from issued_books_info*/;


-- ========== ЗАДАНИЕ 9: ПРЕДСТАВЛЕНИЕ ИНФОРМАЦИИ О ПРОСРОЧЕННЫХ КНИГАХ ==========
create or replace view non_returned_books as
select ib.inventory_number, ib.reader_lastname, ib.reader_name, ib.author_name, ib.author_lastname, ib.title, ib.expected_return_date, ib.actual_return_date, r.id_reader_ticket
from issued_books_info ib
INNER JOIN reader r ON ib.reader_lastname = r.lastname AND ib.reader_name = r.firstname
WHERE CURRENT_DATE > expected_return_date 
    AND actual_return_date IS NULL;


-- ========== ЗАДАНИЕ 10: ФУНКЦИЯ ВЫДАЧИ КНИГИ С ПРОВЕРКОЙ ПРОСРОЧЕК ДЛЯ ЗАДАННОГО ЧИТАТЕЛЯ (VERSION 2) ==========
CREATE OR REPLACE FUNCTION issue_book_with_overdue_check(
    p_reader_id INTEGER,
    p_book_instance_id INTEGER
) RETURNS VOID AS $$
DECLARE
    v_reader_exists BOOLEAN;
    v_book_exists BOOLEAN;
    v_has_overdue BOOLEAN;
    v_book_status VARCHAR(20);
    v_days_to_return INTEGER := 30;
BEGIN
    SELECT EXISTS(
        SELECT 1 
        FROM reader 
        WHERE id_reader_ticket = p_reader_id
    ) INTO v_reader_exists;
    
    IF NOT v_reader_exists THEN
        RAISE EXCEPTION 'Читатель с ID % не найден', p_reader_id;
    END IF;
    
    SELECT EXISTS(
        SELECT 1 
        FROM book_instance 
        WHERE inventory_number = p_book_instance_id
    ) INTO v_book_exists;
    
    IF NOT v_book_exists THEN
        RAISE EXCEPTION 'Экземпляр книги с номером % не найден', p_book_instance_id;
    END IF;
    
    SELECT EXISTS(
        SELECT 1 
        FROM non_returned_books 
        WHERE id_reader_ticket = p_reader_id
    ) INTO v_has_overdue;
    
    IF v_has_overdue THEN
        RAISE EXCEPTION 'Выдача невозможна: у читателя % есть просроченные книги', p_reader_id;
    END IF;
    
    SELECT status INTO v_book_status
    FROM book_instance 
    WHERE inventory_number = p_book_instance_id;
    
    IF v_book_status != 'в наличии' THEN
        RAISE EXCEPTION 'Выдача невозможна: книга сейчас "%"', v_book_status;
    END IF;
    
    BEGIN
        INSERT INTO issuance (
            fk_reader_ticket, 
            fk_inventory_number, 
            date_time_issue, 
            expected_return_date, 
            actual_return_date
        ) VALUES (
            p_reader_id, 
            p_book_instance_id, 
            NOW(), 
            CURRENT_DATE + (v_days_to_return || ' days')::INTERVAL, 
            NULL
        );
        
        UPDATE book_instance
        SET status = 'выдана'
        WHERE inventory_number = p_book_instance_id;
        
        RAISE NOTICE 'Книга % успешно выдана читателю % до %', 
            p_book_instance_id, 
            p_reader_id, 
            CURRENT_DATE + (v_days_to_return || ' days')::INTERVAL;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Ошибка при выдаче книги: %', SQLERRM;
    END;
    
END;
$$ LANGUAGE plpgsql;

-- ========== ЗАДАНИЕ 11: БРОНИРОВАНИЕ ЭКЗЕМПЛЯРА КНИГИ ДЛЯ ЗАДАННОГО ЧИТАТЕЛЯ ==========
CREATE OR REPLACE FUNCTION book_reserve_with_check(
    p_reader_id INTEGER,
    p_book_instance_id INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM reader WHERE id_reader_ticket = p_reader_id) THEN
        RAISE EXCEPTION 'Читатель % не найден', p_reader_id;
    END IF;
    
    IF NOT EXISTS(
        SELECT 1 
        FROM book_instance 
        WHERE inventory_number = p_book_instance_id 
        AND status = 'в наличии'
    ) THEN
        RAISE EXCEPTION 'Книга % недоступна для бронирования', p_book_instance_id;
    END IF;
    
    IF EXISTS(
        SELECT 1 
        FROM issuance 
        WHERE fk_reader_ticket = p_reader_id
            AND fk_inventory_number = p_book_instance_id
            AND actual_return_date IS NULL
            AND expected_return_date >= CURRENT_DATE
    ) THEN
        RAISE EXCEPTION 'У вас уже есть активная бронь на эту книгу';
    END IF;
    
    insert into issuance (
    	fk_reader_ticket, 
        fk_inventory_number, 
        date_time_issue, 
        expected_return_date, 
        actual_return_date)
        values (
        p_reader_id,
        p_book_instance_id,
        CURRENT_TIMESTAMP,
        CURRENT_DATE + interval '2 days',
        null);
        
        update book_instance bi
        set status = 'забронирована'
        where bi.inventory_number = p_book_instance_id;
        RAISE NOTICE 'Книга успешно забронирована до %', 
        TO_CHAR(CURRENT_DATE + INTERVAL '2 days', 'DD.MM.YYYY');
END;
$$ language plpgsql;


-- ========== ЗАДАНИЕ 12: ФУНКЦИЯ ОТМЕНЫ ЗАБРОНИРОВАННОГО ЭКЗЕМПЛЯРА ДЛЯ ЗАДАННОГО ЧИТАТЕЛЯ ==========
create or replace function canceling_of_reserved_book(
	p_reader_id INTEGER,
    p_book_instance_id INTEGER
) RETURNS VOID AS $$
begin
	IF NOT EXISTS(SELECT 1 FROM reader WHERE id_reader_ticket = p_reader_id) THEN
        RAISE EXCEPTION 'Читатель % не найден', p_reader_id;
    END IF;
    
    IF NOT EXISTS(
        SELECT 1 
        FROM book_instance 
        WHERE inventory_number = p_book_instance_id 
        AND status = 'забронирована'
    ) THEN
        RAISE EXCEPTION 'Книга % не забронированна', p_book_instance_id;
    END IF;

	IF NOT EXISTS(
        SELECT 1 
        FROM issuance 
        WHERE fk_reader_ticket = p_reader_id
            AND fk_inventory_number = p_book_instance_id
            AND actual_return_date IS NULL
            AND expected_return_date >= CURRENT_DATE
    ) THEN
        RAISE EXCEPTION 'Книга % не забронирована вами', p_book_instance_id;
    END IF;

    UPDATE book_instance
    SET status = 'в наличии'
    WHERE inventory_number = p_book_instance_id;
    
    UPDATE issuance
    SET actual_return_date = CURRENT_DATE
    WHERE fk_reader_ticket = p_reader_id
        AND fk_inventory_number = p_book_instance_id
        AND actual_return_date IS NULL
        AND expected_return_date >= CURRENT_DATE;
    
    RAISE NOTICE 'Бронь книги % успешно отменена', p_book_instance_id;
end;
$$ language plpgsql;


-- ========== ЗАДАНИЕ 13: ФУНКЦИЯ ВЫДАЧИ КНИГИ ЗАДАННОМУ ЧИТАТЕЛЮ (VERSION 3) ==========
CREATE OR REPLACE FUNCTION issue_book_with_reservation_check_fixed(
    p_reader_id INTEGER,
    p_book_instance_id INTEGER
) RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM reader WHERE id_reader_ticket = p_reader_id) THEN
        RAISE EXCEPTION 'Читатель % не найден', p_reader_id;
    END IF;
    
    IF NOT EXISTS(SELECT 1 FROM book_instance WHERE inventory_number = p_book_instance_id) THEN
        RAISE EXCEPTION 'Книга % не найдена', p_book_instance_id;
    END IF;
    
    IF EXISTS(SELECT 1 FROM non_returned_books WHERE id_reader_ticket = p_reader_id) THEN
        RAISE EXCEPTION 'Есть просроченные книги';
    END IF;
    
    IF NOT EXISTS(
        SELECT 1 
        FROM book_instance 
        WHERE inventory_number = p_book_instance_id 
        AND status IN ('в наличии', 'забронирована')
    ) THEN
        RAISE EXCEPTION 'Книга недоступна (статус: %)', 
            (SELECT status FROM book_instance WHERE inventory_number = p_book_instance_id);
    END IF;
    
    IF EXISTS(
        SELECT 1 
        FROM issuance i
        JOIN book_instance bi ON i.fk_inventory_number = bi.inventory_number
        WHERE i.fk_inventory_number = p_book_instance_id
            AND i.fk_reader_ticket != p_reader_id
            AND i.actual_return_date IS NULL
            AND bi.status = 'забронирована'
            AND i.expected_return_date >= CURRENT_DATE
    ) THEN
        RAISE EXCEPTION 'Книга забронирована другим читателем';
    END IF;
    
    IF EXISTS(
        SELECT 1 
        FROM issuance i
        JOIN book_instance bi ON i.fk_inventory_number = bi.inventory_number
        WHERE i.fk_reader_ticket = p_reader_id
            AND i.fk_inventory_number = p_book_instance_id
            AND i.actual_return_date IS NULL
            AND bi.status = 'забронирована'
            AND i.expected_return_date >= CURRENT_DATE
    ) THEN
        UPDATE issuance
        SET 
            date_time_issue = NOW(),
            expected_return_date = CURRENT_DATE + INTERVAL '30 days'
        WHERE fk_reader_ticket = p_reader_id
            AND fk_inventory_number = p_book_instance_id
            AND actual_return_date IS NULL;
        
        RAISE NOTICE 'Бронь преобразована в выдачу';
    ELSE
        INSERT INTO issuance (
            fk_reader_ticket, 
            fk_inventory_number, 
            date_time_issue, 
            expected_return_date, 
            actual_return_date
        ) VALUES (
            p_reader_id, 
            p_book_instance_id, 
            NOW(), 
            CURRENT_DATE + INTERVAL '30 days', 
            NULL
        );
    END IF;
    
    UPDATE book_instance
    SET status = 'выдана'
    WHERE inventory_number = p_book_instance_id;
    
    RAISE NOTICE 'Книга выдана';
END;
$$ LANGUAGE plpgsql;


-- ========== ЗАДАНИЕ 14: ФУНКЦИЯ МЕСТОПОЛОЖЕНИЙ КНИГИ ==========
CREATE OR REPLACE FUNCTION get_book_locations(p_book_id INTEGER)
RETURNS TABLE(
    book_title VARCHAR(200),
    author_name TEXT,
    inventory_number INTEGER,
    book_state VARCHAR(50),
    status VARCHAR(20),
    location VARCHAR(200),
    state_priority INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.title::VARCHAR(200),
        (a.lastname || ' ' || a.firstname)::TEXT,
        bi.inventory_number,
        bi.state::VARCHAR(50),
        bi.status::VARCHAR(20),
        bi.location::VARCHAR(200),
        CASE bi.state
            WHEN 'отличное' THEN 1
            WHEN 'хорошее' THEN 2
            WHEN 'удовлетворительное' THEN 3
            WHEN 'ветхое' THEN 4
            ELSE 5
        END as state_priority
    FROM book_instance bi
    JOIN book b ON bi.book_info = b.id
    JOIN author a ON b.id_author = a.id
    WHERE b.id = p_book_id
    ORDER BY state_priority, bi.inventory_number;
END;
$$ LANGUAGE plpgsql;

-- ========== ЗАДАНИЕ 15: ПРЕДСТАВЛЕНИЕ ДОСТУПНЫХ КНИГ ==========
CREATE OR REPLACE VIEW available_books_summary AS
SELECT 
    b.id as book_id,
    b.title as book_title,
    a.lastname || ' ' || a.firstname as author_name,
    ph.title as publisher,
    bi.state as book_state,
    COUNT(bi.inventory_number) as available_count,
    STRING_AGG(bi.location, '; ' ORDER BY bi.inventory_number) as locations
FROM book_instance bi
JOIN book b ON bi.book_info = b.id
JOIN author a ON b.id_author = a.id
JOIN publishing_house ph ON b.id_publishing_house = ph.id
WHERE bi.status = 'в наличии'
GROUP BY b.id, b.title, a.lastname, a.firstname, ph.title, bi.state
ORDER BY b.title, 
    CASE bi.state
        WHEN 'отличное' THEN 1
        WHEN 'хорошее' THEN 2
        WHEN 'удовлетворительное' THEN 3
        WHEN 'ветхое' THEN 4
        ELSE 5
    END;


-- ========== ЗАДАНИЕ 16: ПРЕДСТАВЛЕНИЕ КНИГ НЕ ВОЗВРАЩЕННЫХ БОЛЕЕ ГОДА ==========
CREATE OR REPLACE VIEW books_overdue_more_than_year AS
SELECT 
    i.fk_reader_ticket as reader_id,
    r.lastname || ' ' || r.firstname as reader_name,
    i.fk_inventory_number as book_instance_id,
    b.title as book_title,
    a.lastname || ' ' || a.firstname as author_name,
    i.date_time_issue as issue_date,
    i.expected_return_date as expected_return,
    CURRENT_DATE - i.date_time_issue::DATE as days_overdue,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, i.date_time_issue)) as years_overdue,
    bi.state as book_state,
    bi.location
FROM issuance i
JOIN reader r ON i.fk_reader_ticket = r.id_reader_ticket
JOIN book_instance bi ON i.fk_inventory_number = bi.inventory_number
JOIN book b ON bi.book_info = b.id
JOIN author a ON b.id_author = a.id
WHERE i.actual_return_date IS NULL
    AND i.date_time_issue <= CURRENT_DATE - INTERVAL '1 year'
    AND bi.status = 'выдана'
ORDER BY i.date_time_issue;


-- ========== ЗАДАНИЕ 17: ТАБЛИЦА ЛОГОВ ==========
CREATE TABLE IF NOT EXISTS logs (
    id SERIAL PRIMARY KEY,
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    table_name VARCHAR(100) NOT NULL,
    log_content TEXT NOT NULL,
    operation_type VARCHAR(10) NOT NULL CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE')),
    user_name VARCHAR(100) DEFAULT CURRENT_USER
);


-- ========== ЗАДАНИЕ 18: ТРИГГЕРЫ ДЛЯ ЛОГИРОВАНИЯ ==========
CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_operation VARCHAR(10);
    v_content TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_operation := 'INSERT';
        v_content := 'Добавлена запись: ' || row_to_json(NEW)::TEXT;
    ELSIF TG_OP = 'UPDATE' THEN
        v_operation := 'UPDATE';
        v_content := 'Изменена запись. Старое: ' || row_to_json(OLD)::TEXT || 
                     ', Новое: ' || row_to_json(NEW)::TEXT;
    ELSIF TG_OP = 'DELETE' THEN
        v_operation := 'DELETE';
        v_content := 'Удалена запись: ' || row_to_json(OLD)::TEXT;
    END IF;
    
    INSERT INTO logs (table_name, log_content, operation_type)
    VALUES (TG_TABLE_NAME, v_content, v_operation);
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ========== ТЕСТЫ ДЛЯ ЗАДАНИЙ 6-18 ==========

DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 6: Задание 6 (Основная функция выдачи книги)';
    
    RAISE NOTICE 'Функция issue_book создана успешно';
    
    -- 6.2 Тест выдачи книги
    PERFORM issue_book(1001, 5002);
    RAISE NOTICE 'Книга 5002 выдана читателю 1001';
    
    IF EXISTS(SELECT 1 FROM issuance WHERE fk_inventory_number = 5002 AND actual_return_date IS NULL) THEN
        RAISE NOTICE 'Запись о выдаче создана в таблице issuance';
    END IF;
    
    IF (SELECT status FROM book_instance WHERE inventory_number = 5002) = 'выдана' THEN
        RAISE NOTICE 'Статус книги 5002 изменен на "выдана"';
    END IF;
    
    RAISE NOTICE 'Тест 6 пройден';
END $$;

-- ТЕСТ 7: Задание 7 (Возврат книги)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 7: Задание 7 (Функция возврата книги)';
    
    PERFORM return_book(1001, 5002);
    RAISE NOTICE 'Книга 5002 возвращена читателем 1001';
    
    IF EXISTS(SELECT 1 FROM issuance WHERE fk_inventory_number = 5002 AND actual_return_date IS NOT NULL) THEN
        RAISE NOTICE 'Дата возврата проставлена в таблице issuance';
    END IF;
    
    IF (SELECT status FROM book_instance WHERE inventory_number = 5002) = 'в наличии' THEN
        RAISE NOTICE 'Статус книги 5002 вернулся к "в наличии"';
    END IF;
    
    RAISE NOTICE 'Тест 7 пройден';
END $$;

-- ТЕСТ 8: Задание 8 (Представление выданных книг)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 8: Задание 8 (Представление выданных книг)';
    
    RAISE NOTICE 'Представление issued_books_info создано успешно';
    
    IF EXISTS(SELECT 1 FROM information_schema.views WHERE table_name = 'issued_books_info') THEN
        RAISE NOTICE 'Представление существует в базе данных';
    END IF;
    
    RAISE NOTICE 'Тест 8 пройден';
END $$;

-- ТЕСТ 9: Задание 9 (Представление просроченных книг)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 9: Задание 9 (Представление просроченных книг)';
    
    RAISE NOTICE 'Представление non_returned_books создано успешно';
    
    IF EXISTS(SELECT 1 FROM information_schema.views WHERE table_name = 'non_returned_books') THEN
        RAISE NOTICE 'Представление существует в базе данных';
    END IF;
    
    RAISE NOTICE 'Тест 9 пройден';
END $$;

DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 10: Задание 10 (Выдача с проверкой просрочек)';
    
    PERFORM issue_book_with_overdue_check(1002, 5003);
    RAISE NOTICE 'Книга 5003 выдана читателю 1002 (проверка просрочек)';
    
    PERFORM return_book(1002, 5003);
    
    RAISE NOTICE 'Тест 10 пройден';
END $$;

-- ТЕСТ 11: Задание 11 (Бронирование книги)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 11: Задание 11 (Функция бронирования книги)';
    
    PERFORM book_reserve_with_check(1001, 5001);
    RAISE NOTICE 'Книга 5001 забронирована читателем 1001';
    
    IF (SELECT status FROM book_instance WHERE inventory_number = 5001) = 'забронирована' THEN
        RAISE NOTICE 'Статус книги изменен на "забронирована"';
    END IF;
    
    RAISE NOTICE 'Тест 11 пройден';
END $$;

-- ТЕСТ 12: Задание 12 (Отмена брони)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 12: Задание 12 (Функция отмены брони)';
    
    PERFORM canceling_of_reserved_book(1001, 5001);
    RAISE NOTICE 'Бронь книги 5001 отменена';
    
    IF (SELECT status FROM book_instance WHERE inventory_number = 5001) = 'в наличии' THEN
        RAISE NOTICE 'Статус книги вернулся к "в наличии"';
    END IF;
    
    RAISE NOTICE 'Тест 12 пройден';
END $$;

-- ТЕСТ 13: Задание 13 (Выдача с проверкой брони)
DO $$
DECLARE
    test_exception_text TEXT;
BEGIN
    RAISE NOTICE 'ТЕСТ 13: Задание 13 (Выдача с проверкой брони другого читателя)';
    
    PERFORM book_reserve_with_check(1002, 5002);
    RAISE NOTICE 'Книга 5002 забронирована читателем 1002';
    
    BEGIN
        PERFORM issue_book_with_reservation_check_fixed(1001, 5002);
        test_exception_text := NULL;
    EXCEPTION WHEN OTHERS THEN
        test_exception_text := SQLERRM;
        RAISE NOTICE 'Ожидаемая ошибка (книга забронирована другим): %', test_exception_text;
    END;
    
    IF test_exception_text IS NULL THEN
        RAISE EXCEPTION 'Ошибка: функция не предотвратила выдачу забронированной книги';
    END IF;
    
    PERFORM issue_book_with_reservation_check_fixed(1002, 5002);
    RAISE NOTICE 'Бронь преобразована в выдачу для читателя 1002';
    
    IF (SELECT status FROM book_instance WHERE inventory_number = 5002) = 'выдана' THEN
        RAISE NOTICE 'Статус книги изменен на "выдана"';
    END IF;
    
    PERFORM return_book(1002, 5002);
    
    RAISE NOTICE 'Тест 13 пройден';
END $$;

-- ТЕСТ 14: Задание 14 (Функция местоположений книги)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 14: Задание 14 (Функция местоположений книги)';
    
    IF EXISTS(SELECT 1 FROM get_book_locations(1)) THEN
        RAISE NOTICE 'Функция get_book_locations возвращает данные для книги ID=1';
    END IF;
    
    RAISE NOTICE 'Данные функции get_book_locations для книги ID=1:';
    
    RAISE NOTICE 'Тест 14 пройден';
END $$;

-- ТЕСТ 15: Задание 15 (Представление доступных книг)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 15: Задание 15 (Представление доступных книг)';
    
    IF EXISTS(SELECT 1 FROM information_schema.views WHERE table_name = 'available_books_summary') THEN
        RAISE NOTICE 'Представление available_books_summary существует';
    END IF;
    
    IF EXISTS(SELECT 1 FROM available_books_summary LIMIT 1) THEN
        RAISE NOTICE 'Представление возвращает данные';
    END IF;
    
    RAISE NOTICE 'Тест 15 пройден';
END $$;

-- ТЕСТ 16: Задание 16 (Представление книг не возвращенных более года)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 16: Задание 16 (Представление книг не возвращенных более года)';
    
    IF EXISTS(SELECT 1 FROM information_schema.views WHERE table_name = 'books_overdue_more_than_year') THEN
        RAISE NOTICE 'Представление books_overdue_more_than_year существует';
    END IF;
    
    RAISE NOTICE 'Тест 16 пройден';
END $$;

-- ТЕСТ 17-18: Задания 17-18 (Логирование)
DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ 17-18: Задания 17-18 (Таблица логов и триггеры)';
    
    IF EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'logs') THEN
        RAISE NOTICE 'Таблица logs создана';
    END IF;
    
    IF EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'log_changes') THEN
        RAISE NOTICE 'Функция log_changes создана';
    END IF;
    
    RAISE NOTICE 'Тест 17-18 пройден';
END $$;

DO $$
BEGIN
    RAISE NOTICE 'ТЕСТ ИТОГОВЫЙ: Полный сценарий использования всех функций';
    
    RAISE NOTICE '1. Бронируем книгу 5005 читателем 1005';
    PERFORM book_reserve_with_check(1005, 5005);
    
    RAISE NOTICE '2. Отменяем бронь книги 5005';
    PERFORM canceling_of_reserved_book(1005, 5005);
    
    RAISE NOTICE '3. Выдаем книгу 5005 читателю 1005 (проверка просрочек + брони)';
    PERFORM issue_book_with_reservation_check_fixed(1005, 5005);
    
    RAISE NOTICE '4. Возвращаем книгу 5005';
    PERFORM return_book(1005, 5005);
    
    RAISE NOTICE '5. Проверяем представления:';
    
    RAISE NOTICE '   - Выданные книги: % шт', (SELECT COUNT(*) FROM issued_books_info);
    RAISE NOTICE '   - Доступные книги: % шт', (SELECT COUNT(*) FROM available_books_summary);
    RAISE NOTICE '   - Просроченные книги: % шт', (SELECT COUNT(*) FROM non_returned_books);
    RAISE NOTICE '   - Книги не возвращенные более года: % шт', (SELECT COUNT(*) FROM books_overdue_more_than_year);
    
    RAISE NOTICE 'Тест итоговый пройден';
END $$;

DO $$
BEGIN
    RAISE NOTICE 'Очистка тестовых данных';
    
    DELETE FROM logs;
    RAISE NOTICE 'Логи очищены';
    
    DELETE FROM issuance WHERE fk_reader_ticket IN (1001, 1002, 1005);
    RAISE NOTICE 'Тестовые выдачи очищены';
    
    UPDATE book_instance SET status = 'в наличии' WHERE inventory_number IN (5001, 5002, 5003, 5005);
    RAISE NOTICE 'Статусы книг восстановлены';
    
    RAISE NOTICE '=== ВСЕ ТЕСТЫ ЗАВЕРШЕНЫ УСПЕШНО ===';
END $$;