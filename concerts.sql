DROP DATABASE IF EXISTS koncerty;
CREATE DATABASE koncerty;
USE koncerty;

CREATE TABLE klienci (
  id_klient int not null auto_increment,
  primary key(id_klient),
  imie varchar(20) not null,
  nazwisko varchar(30) not null,
  email varchar(100) not null,
  telefon varchar(20) default null,
  miasto varchar(30) default null,
  ulica varchar(30) default null,
  kod_pocztowy varchar(6) default null,
  nr varchar(6) default null
);

CREATE TABLE obiekty (
  id_obiekt int not null auto_increment,
  primary key(id_obiekt),
  nazwa varchar(100) not null,
  miasto varchar(30) not null,
  ulica varchar(30) not null,
  kod_pocztowy varchar(6) not null,
  nr varchar(6) not null
);

CREATE TABLE koncerty (
  id_koncert int not null auto_increment,
  primary key(id_koncert),
  id_obiekt int not null,
  foreign key(id_obiekt) references obiekty(id_obiekt),
  nazwa varchar(255) not null,
  data_koncertu datetime not null
);

CREATE TABLE zamowienia (
  id_zamowienie int not null auto_increment,
  primary key(id_zamowienie),
  id_klient int not null,
  foreign key(id_klient) references klienci(id_klient),
  kwota decimal(10,2) default 0.0,
  status varchar(20) default "niezrealizowane"
);

CREATE TABLE transakcje (
  id_transakcja int not null auto_increment,
  primary key(id_transakcja),
  id_zamowienie int not null,
  foreign key(id_zamowienie) references zamowienia(id_zamowienie),
  kwota decimal(10,2) not null,
  data_transakcji datetime not null
);

CREATE TABLE typybiletow (
  id_typbiletu int not null auto_increment,
  primary key(id_typbiletu),
  id_koncert int not null,
  foreign key(id_koncert) references koncerty(id_koncert),
  nazwa varchar(50) default null,
  miejsce varchar(50) default null,
  cena decimal(6,2)
);

CREATE TABLE bilety (
  id_bilet int not null auto_increment,
  primary key(id_bilet),
  id_zamowienie int not null,
  foreign key(id_zamowienie) references zamowienia(id_zamowienie),
  id_typbiletu int not null,
  foreign key(id_typbiletu) references typybiletow(id_typbiletu),
  forma_biletu varchar(15) not null,
  ilosc int not null
);

CREATE INDEX idx_koncert_nazwa ON koncerty(nazwa);
CREATE INDEX idx_miasto ON obiekty(miasto);
CREATE INDEX idx_cena ON typybiletow(cena);

-- trigger walidujący adres email
delimiter $$
CREATE TRIGGER walidacja_email BEFORE INSERT ON klienci
FOR EACH ROW
BEGIN
  IF NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nieprawidłowy adres email';
  END IF;
END;
$$
delimiter ;

-- trigger aktualizujący kwotę zamówienia po dodaniu biletu
delimiter $$
CREATE TRIGGER after_insert_bilet AFTER INSERT ON bilety
FOR EACH ROW
BEGIN
  SET @suma = 0.0;

  SELECT sum(typybiletow.cena * bilety.ilosc) INTO @suma
  FROM bilety NATURAL JOIN typybiletow  
  WHERE bilety.id_zamowienie = NEW.id_zamowienie;

  UPDATE zamowienia SET kwota = @suma
  WHERE zamowienia.id_zamowienie = NEW.id_zamowienie;
END;
$$
delimiter ;

-- trigger aktualizujący kwotę zamówienia po usunięciu biletu
delimiter $$
CREATE TRIGGER after_delete_bilet AFTER DELETE ON bilety
FOR EACH ROW
BEGIN
  SET @suma = 0.0;
  
  SELECT sum(typybiletow.cena * bilety.ilosc) INTO @suma
  FROM bilety NATURAL JOIN typybiletow
  WHERE bilety.id_zamowienie = OLD.id_zamowienie;

  UPDATE zamowienia SET kwota = @suma
  WHERE zamowienia.id_zamowienie = OLD.id_zamowienie;
END;
$$
delimiter ;


-- trigger aktualizujący status zamówienia na "opłacone" po dodaniu transakcji
delimiter $$
CREATE TRIGGER after_insert_transakcje AFTER INSERT ON transakcje
FOR EACH ROW
BEGIN
  UPDATE zamowienia SET status = "opłacone"
  WHERE zamowienia.id_zamowienie = NEW.id_zamowienie;
END;
$$
delimiter ;


-- procedura dodająca bilet do zamówienia
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `dodaj_bilet`(
  IN `id_klient` INT, 
  IN `id_typbiletu` INT, 
  IN `forma_biletu` VARCHAR(20), 
  IN `ilosc` INT
)
BEGIN

  SET @id_zam = null;

  -- sprawdź czy istnieje niezrealizowane zamówienie przypisane do danego klienta
  SELECT zamowienia.id_zamowienie INTO @id_zam 
  FROM zamowienia
  WHERE zamowienia.id_klient = id_klient AND zamowienia.status = "niezrealizowane";


  IF @id_zam IS null THEN
    -- dodanie nowego zamówienia dla danego klienta
    INSERT INTO zamowienia(id_klient) 
    VALUES (id_klient);
 
    SELECT zamowienia.id_zamowienie INTO @id_zam
    FROM zamowienia
    WHERE zamowienia.id_klient = id_klient AND zamowienia.status = "niezrealizowane";
  END IF;

  -- dodanie biletu powiązanego z danym zamówieniem
  INSERT INTO bilety (id_zamowienie, id_typbiletu, forma_biletu, ilosc)
  VALUES (@id_zam, id_typbiletu, forma_biletu, ilosc);

END;
$$
DELIMITER ;

-- procedura dodająca transakcję do zamówienia
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `dodaj_transakcje`(
  IN `id_zamowienie` INT
)
BEGIN

  SET @kwota = 0.0;

  SELECT zamowienia.kwota INTO @kwota 
  FROM zamowienia
  WHERE zamowienia.id_zamowienie = id_zamowienie;

  INSERT INTO transakcje(id_zamowienie, kwota, data_transakcji)
  VALUES (id_zamowienie, @kwota, now());
END$$
DELIMITER ;

-- procedura wyświetająca bilety dla danego klienta
DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `pokaz_bilety`(
  IN `id_klient` INT
)
BEGIN

  SELECT koncerty.nazwa AS koncert, koncerty.data_koncertu, obiekty.nazwa AS miejsce, obiekty.miasto, typybiletow.cena, bilety.ilosc
  FROM koncerty JOIN typybiletow ON koncerty.id_koncert = typybiletow.id_koncert
  JOIN obiekty ON koncerty.id_obiekt = obiekty.id_obiekt
  JOIN bilety ON typybiletow.id_typbiletu = bilety.id_typbiletu
  JOIN zamowienia ON bilety.id_zamowienie = zamowienia.id_zamowienie
  WHERE zamowienia.id_klient = id_klient;

END;
$$
DELIMITER ;

-- dodanie przykładowych danych
INSERT INTO obiekty (nazwa, miasto, kod_pocztowy, ulica, nr) VALUES
("PGE Narodowy", "Warszawa", "03-901", "Al. Księcia Józefa Poniatowskiego", "1"),
("Atlas Arena", "Łódź", "94-020", "Al. ks. bp. Władysława Bandurskiego", "7"),
("TAURON Arena Kraków", "Kraków", "31-571", "Stanisława Lema", "7"),
("Arena Gliwice", "Gliwice", "44-100", "Akademicka", "50"),
("Opera Leśna", "Sopot", "81-829", "Stanisława Moniuszki", "12"),
("Lotnisko Gdynia - Kosakowo", "Gdynia", "81-382", "Al. Marszałka Piłsudskiego", "52/54"),
("Płock, plaża nad Wisłą", "Płock", "09-401", "Rybaki", "9"),
("Hala Stulecia", "Wrocław", "51-618", "Wystawowa", "1"),
("Hala Spodek", "Katowice", "40-005", "Al. Wojciecha Korfantego", "35"),
("COS Torwar", "Warszawa", "00-449", "Łazienkowska", "6A");

INSERT INTO koncerty (id_obiekt, nazwa, data_koncertu) VALUES
(6, "Open'er Festival 2023", "2023-06-28 00:00:00"),
(7, "Audioriver Festival 2023", "2023-07-28 00:00:00"),
(7, "Lech Polish Hip-Hop Festival", "2023-07-06 00:00:00"),
(1, "Imagine Dragons - Mercury World Tour", "2023-08-14 17:00:00"),
(5, "Dawid Podsiadło: PRZED I PO TOUR", "2023-06-11 21:00:00"),
(1, "P!NK: Summer Carnival 2023", "2023-07-16 17:00:00"),
(1, "The Weeknd: After Hours Til Dawn Tour", "2023-08-09 17:00:00"),
(2, "Niall Horan: The Show", "2024-03-18 18:00:00"),
(3, "Sting: My Songs 2023", "2023-07-20 18:00:00");

INSERT INTO typybiletow (id_koncert, nazwa, miejsce, cena) VALUES
(4, "Miejsce stojące", "Płyta", 649.0),
(5, null, "Sektor O", 239.0),
(5, null, "Sektor L", 269.0),
(6, "Miejsce stojące", "Płyta 1", 615.0),
(6, "Miejsce stojące", "Płyta 2", 400.0),
(6, null, "Sektor D15", 550.0),
(7, "Miejsce stojące", "Płyta", 643.0),
(7, "VIP", "D14", 1045.0),
(8, "Miejsce stojące", "Płyta", 230.0),
(8, "VIP", "Sektor A", 345.0),
(1, "Dzień 1 - 28.06.2023", null, 449.0),
(1, "Karnet 4-dniowy", null, 949.0),
(1, "Karnety weekendowe", null, 689.0),
(2, "Karnet 3-dniowy", null, 550.0),
(2, "Karnet 2-dniowy", null, 440.0),
(3, "Karnet 3-dniowy", null, 490.0),
(3, "Karnet 3-dniowy VIP", null, 1500.0);

INSERT INTO klienci (imie, nazwisko, email, telefon, miasto, kod_pocztowy, ulica, nr) VALUES
("Maksymilian", "Jankowski", "m.jan@gmail.com", "456 123 457", "Warszawa", "00-811", "Towarowa", "2"),
("Ola", "Piotrowska", "o.piotrowska@wp.pl", "852 963 741", "Łódź", "90-005", "Piotrowska", "2a");

INSERT INTO klienci (imie, nazwisko, email, telefon) VALUES
("Hubert", "Dąbrowski", "huber.dabr@gmail.com", "789 562 336"),
("Olaf", "Ziółkowski", "olafz@wp.pl", null),
("Laura", "Wróblewska", "laura.wroblewska@gmail.com", "741 852 963"),
("Kinga", "Maciejewska", "k.maciejewska@gmail.com", null),
("Anna", "Kowalska", "anna.kowal@gmail.com", "632 564 412");

CALL dodaj_bilet(1, 4, "elektroniczny", 1);
CALL dodaj_bilet(1, 3, "papierowy", 1);
CALL dodaj_bilet(5, 9, "elektroniczny", 2);
CALL dodaj_bilet(4, 15, "elektroniczny", 1);
CALL dodaj_bilet(2, 6, "papierowy", 2);
CALL dodaj_bilet(6, 16, "elektroniczny", 1);
CALL dodaj_bilet(4, 1, "elektroniczny", 1);
CALL dodaj_bilet(7, 2, "elektroniczny", 1);

CALL dodaj_transakcje(4);
CALL dodaj_transakcje(1);
CALL dodaj_transakcje(3);

-- przykładowe zapytania do bazy danych
SELECT koncerty.nazwa, obiekty.miasto, obiekty.nazwa as miejsce, typybiletow.cena
FROM koncerty, obiekty, typybiletow
WHERE koncerty.id_koncert = typybiletow.id_koncert AND koncerty.id_obiekt = obiekty.id_obiekt;

SELECT * FROM transakcje NATURAL JOIN zamowienia NATURAL JOIN klienci;

SELECT koncerty.nazwa, obiekty.nazwa as obiekt, typybiletow.miejsce, typybiletow.nazwa
FROM koncerty INNER JOIN obiekty ON koncerty.id_obiekt = obiekty.id_obiekt INNER JOIN typybiletow ON typybiletow.id_koncert = koncerty.id_koncert;

SELECT transakcje.id_transakcja, transakcje.data_transakcji, transakcje.kwota, zamowienia.status, klienci.email
FROM transakcje LEFT JOIN zamowienia ON zamowienia.id_zamowienie = transakcje.id_zamowienie LEFT
JOIN klienci ON klienci.id_klient = zamowienia.id_klient;

SELECT typybiletow.id_typbiletu, typybiletow.cena, obiekty.nazwa as obiekt, koncerty.nazwa
FROM obiekty RIGHT JOIN koncerty ON obiekty.id_obiekt = koncerty.id_obiekt RIGHT JOIN typybiletow ON typybiletow.id_koncert = koncerty.id_koncert;

SELECT typybiletow.cena, typybiletow.nazwa, typybiletow.miejsce, koncerty.nazwa as koncert
FROM typybiletow, koncerty
WHERE typybiletow.id_koncert = koncerty.id_koncert AND typybiletow.cena BETWEEN 400 AND 600
ORDER BY typybiletow.cena;

SELECT koncerty.nazwa as koncert, koncerty.data_koncertu, typybiletow.nazwa, typybiletow.miejsce
FROM koncerty, typybiletow WHERE koncerty.id_koncert = typybiletow.id_koncert AND typybiletow.miejsce
LIKE "%Płyta%";

-- Zlicza ilość koncertów w każdym mieście, grupując wyniki po mieście obiektu
SELECT count(koncerty.id_koncert) as ilosc_koncertow, obiekty.miasto
FROM koncerty, obiekty
WHERE obiekty.id_obiekt = koncerty.id_obiekt
GROUP BY obiekty.miasto;

-- Sumuje kwoty zamówień dla każdego statusu zamówienia, grupując wyniki po statusie
SELECT sum(zamowienia.kwota) AS suma, zamowienia.status 
FROM zamowienia 
GROUP BY zamowienia.status;

-- Sumuje ceny biletów dla każdego klienta, grupując wyniki po ID klienta, tylko dla klientów, którzy wydali więcej niż 500
SELECT sum(typybiletow.cena) as suma, klienci.imie, klienci.nazwisko, klienci.email
FROM bilety JOIN typybiletow ON typybiletow.id_typbiletu = bilety.id_typbiletu
JOIN zamowienia ON bilety.id_zamowienie = zamowienia.id_zamowienie
JOIN klienci ON zamowienia.id_klient = klienci.id_klient
GROUP BY klienci.id_klient
HAVING suma > 500;