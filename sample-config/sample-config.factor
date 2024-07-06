! Copyright (C) 2024 Aleksander Sabak.
! See https://factorcode.org/license.txt for BSD license.
USING: discord ;
IN: mycelium.config


CONSTANT: mycelium-config
  T{ discord-bot-config
    { client-id "1234567890" }
    { client-secret "CHANGEME" }
    { token "CHANGEME" }
    { application-id "1234567890" }
    { obey-names HS{ "username" } }
    ! { user-callback [ mycelium-handler ] }
    ! { guild-id "1039343028357300335" }
    ! { channel-id "1089175837623980092" }
    { permissions 12345667890 }
  }
