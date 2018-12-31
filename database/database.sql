-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle tbl_rezepte
--

CREATE TABLE IF NOT EXISTS tbl_rezepte (
  `rezept_id` int(11) NOT NULL AUTO_INCREMENT,
  `bezeichnung` varchar(200) DEFAULT NULL,
  `anleitung` text,
  PRIMARY KEY (`rezept_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

--
-- Daten für Tabelle tbl_rezepte
--

INSERT INTO tbl_rezepte (rezept_id, bezeichnung, anleitung) VALUES
(1, 'Semmeln', 'Vorteigzutaten mischen, mehrere Stunden gehen lassen. Mit den restlichen Zutaten verkneten und 1 Stunde gehen lassen. 12 Brötchen von 66-67g formen und mit dem Teigschluss nach unten ca. 20min gehen lassen. Brötchen länglich formen und mit dem Teigschluss nach unten weitere 20min gehen lassen, währenddessen den Ofen auf 220° Umluft vorheizen. Brötchen umdrehen, längs einschneiden und mit Dampf 15min backen.'),
(2, 'Brot', 'Mehl rein und backen!');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle tbl_rezept_tags
--

CREATE TABLE IF NOT EXISTS tbl_rezept_tags (
  `rezept_id` int(11) NOT NULL,
  `tag` varchar(50) NOT NULL,
  PRIMARY KEY (`rezept_id`,`tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Daten für Tabelle tbl_rezept_tags
--

INSERT INTO tbl_rezept_tags (rezept_id, tag) VALUES
(1, 'Brötchen');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle tbl_rezept_teile
--

CREATE TABLE IF NOT EXISTS tbl_rezept_teile (
  `rezept_teil_id` int(11) NOT NULL AUTO_INCREMENT,
  `rezept_id` int(11) NOT NULL,
  `bezeichnung` varchar(50) DEFAULT NULL,
  `reihenfolge` int(11) DEFAULT NULL,
  PRIMARY KEY (`rezept_teil_id`),
  KEY `tbl_rezept_teile_ibfk_1` (`rezept_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

--
-- Daten für Tabelle tbl_rezept_teile
--

INSERT INTO tbl_rezept_teile (rezept_teil_id, rezept_id, bezeichnung, reihenfolge) VALUES
(1, 1, 'Vorteig', 1),
(2, 1, 'Hauptteig', 2);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle tbl_rezept_zutaten
--

CREATE TABLE IF NOT EXISTS tbl_rezept_zutaten (
  `rezept_zutat_id` int(11) NOT NULL AUTO_INCREMENT,
  `rezept_id` int(11) NOT NULL,
  `rezept_teil_id` int(11) NOT NULL,
  `zutat` varchar(50) NOT NULL,
  `reihenfolge` int(11) DEFAULT NULL,
  `menge` decimal(10,2) DEFAULT NULL,
  `mengeneinheit` varchar(20) DEFAULT NULL,
  `bemerkung` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`rezept_zutat_id`),
  KEY `rezept_teil_id` (`rezept_teil_id`),
  KEY `zutat_id` (`zutat`),
  KEY `tbl_rezept_zutaten_ibfk_1` (`rezept_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8;

--
-- Daten für Tabelle tbl_rezept_zutaten
--

INSERT INTO tbl_rezept_zutaten (rezept_zutat_id, rezept_id, rezept_teil_id, zutat, reihenfolge, menge, mengeneinheit, bemerkung) VALUES
(1, 1, 1, 'Mehl', 1, '50.00', 'g', NULL),
(2, 1, 1, 'Wasser', 2, '50.00', 'g', NULL),
(3, 1, 1, 'Hefe', 3, '10.00', 'g', NULL),
(4, 1, 2, 'Mehl', 1, '450.00', 'g', NULL),
(5, 1, 2, 'Wasser', 2, '250.00', 'g', NULL),
(6, 2, 2, 'Salz', 3, '1.00', 'Tl', NULL);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle w_zutaten
--

CREATE TABLE IF NOT EXISTS w_zutaten (
  `zutat` varchar(50) NOT NULL,
  `mengeneinheit` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`zutat`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Daten für Tabelle w_zutaten
--

INSERT INTO w_zutaten (zutat, mengeneinheit) VALUES
('Hefe', 'g'),
('Mehl', 'g'),
('Salz', 'Tl'),
('Wasser', 'ml');

--
-- Constraints der exportierten Tabellen
--

--
-- Constraints der Tabelle tbl_rezept_tags
--
ALTER TABLE tbl_rezept_tags
  ADD CONSTRAINT `tbl_rezept_tags_ibfk_2` FOREIGN KEY (`rezept_id`) REFERENCES tbl_rezepte (`rezept_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints der Tabelle tbl_rezept_teile
--
ALTER TABLE tbl_rezept_teile
  ADD CONSTRAINT `tbl_rezept_teile_ibfk_1` FOREIGN KEY (`rezept_id`) REFERENCES tbl_rezepte (`rezept_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints der Tabelle tbl_rezept_zutaten
--
ALTER TABLE tbl_rezept_zutaten
  ADD CONSTRAINT `tbl_rezept_zutaten_ibfk_1` FOREIGN KEY (`rezept_id`) REFERENCES tbl_rezepte (`rezept_id`) ON DELETE CASCADE ON UPDATE CASCADE;
