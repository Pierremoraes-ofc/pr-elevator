##  PierreMoraes
Discord: pierre4235

##  Thanks to those who helped me
[G5](https://github.com/ggfto)

[SubZero](https://github.com/SubZer0GLX)

[MRI-Team](https://docs.mriqbox.com.br/)

[J.J.](https://github.com/JJ4hts)


Original script
[NYXdevelopments](https://github.com/NYXdevelopments/nyx-elevator/)

##  System info
This elevator system can be used in different ways.
1. Gang elevator
2. Work elevator
3. Password elevator
4. Public elevators
5. Card access elevator (using metadata)
6. Teleport system allows lift for vehicles.

##  Settings 
```lua
Config                = {}
Config.Debug          = false              --  Debug mode | true = enabled | false = disabled
Config.WaitTime       = 3000               --  This will set the time for the ProgressBar | 1000 = 1 second
Config.UseLanguage    = "pt"               --  make new languages to your own likng
Config.KeyBind        = 'F6'               --  Keybind for open menu Admin
Config.OpenKeybind    = true               --  If you use a Scripts management menu, disable this option.
Config.UseDatabase    = true               --  Don't touch it if you don't know what you're doing
Config.UseSoundEffect = true               --  makes a sound when you use elevator Note: still a work in progress
Config.keycard        = 'security_card_01' --  Item used to open certain elevators
Config.position       = 'center-left'      --  oxLib notifications position
Config.addCard        = 'addcard'          --  Command to add item to inventory
Config.Raycast        = true               --  If you want to use the raycast feature, disable this option.
Config.RaycastCommand = 'rayo'              --  Keybind to use raycast
Config.Jobs           = {                   --  Jobs used in your city to avoid conflict with card metadata security_card_01
    'police',
    'sheriff',
    'ambulance',
    'mechanic',
}
Config.Locals = {}                          --  Field used to place all the translation for your language
``` 


##  Server.lua
```lua
lib.addCommand('elevador', {                --  Command used to open the menu in Scripts management menu
    help = Config.Locals[Config.UseLanguage].helpcomm,
    restricted = 'group.admin'
}, function(source, args, raw)
    TriggerClientEvent('nyx-elevator:client:startLiftCreator', source)
end)
```

##  Item Ox_inventory
```lua
["security_card_01"] = {
    label = "Cartão de Segurança A",
    weight = 0,
    stack = true,
    close = true,
    description = "Um cartão de segurança... Me pergunto para o que serve",
    client = {
        image = "security_card_01.png",
    },
},
```

##  Database
Although the system checks and creates a database if you don't have one, there is a database if you want to install it manually.
```sql
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
```


##  Image Item
Place your item images in: `ox_inventory/web/images/`

![Security Card Example](https://imgur.com/9pZlbJ6)

##  Preview

[![PR Elevator System Preview](https://img.youtube.com/vi/r9lqe6dXAK8/0.jpg)](https://youtu.be/r9lqe6dXAK8)



# Depedency
1. [Qbox](https://qbox-project.github.io/) or [qb-core](https://github.com/qbcore-framework/qb-core)
2. [oxlib](https://overextended.dev/ox_lib)
3. [ox_inventory](https://overextended.dev/ox_inventory)
I modified this interact so that obstacles such as vehicles, pedestrians, players when in front of the interact disappear but the elevator stops working with vehicles.
4. [interact](https://github.com/Pierremoraes-ofc/interact) 
Original interact, this one works with vehicles or the elevator
[interact](https://github.com/darktrovx/interact)