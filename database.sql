CREATE TABLE IF NOT EXISTS `elevators` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `keypass` varchar(155) NOT NULL,
  `tipo` varchar(155) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `elevator_floors` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `elevator_id` int(11) NOT NULL,
  `floor_number` int(11) NOT NULL,
  `coords` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `elevator_id` (`elevator_id`),
  CONSTRAINT `elevator_floors_ibfk_1` FOREIGN KEY (`elevator_id`) REFERENCES `elevators` (`id`) ON DELETE CASCADE
);