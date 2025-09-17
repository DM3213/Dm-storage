CREATE TABLE IF NOT EXISTS `Dm_storage` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model` varchar(100) DEFAULT NULL,
  `coords` longtext DEFAULT NULL,
  `type` varchar(32) NOT NULL,
  `options` longtext DEFAULT NULL,
  `name` varchar(64) DEFAULT NULL,
  `owner` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

