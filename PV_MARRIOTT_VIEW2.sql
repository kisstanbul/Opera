CREATE OR REPLACE VIEW PV_MARRIOTT_VIEW2 AS
    SELECT resort HotelNo
         , confirmation_no RezNo
         , arrival_date TarihGiris
         , departure_date TarihCikis
         , last_name Soyad
         , currency_code Rez_Doviz
         , guest_country Rez_Ulke
         , insert_date TarihKayit
         , business_date_created TarihSatis
         , '-' Rez_EB
         , repeat_yn Rez_VIP
         , reservation_date TarihKalis
         , no_rooms OdaSayisi
         , adults Yetiskin
         , PaidChild CocukUcretli
         , PaidChild CocukUcretsiz
         , Baby Bebek
         , 0 FiyatPlanlanan
         , 0 FiyatBasilan
         , 0 Cast_Anlasma
         , travel_agent Acenta
         , '-' DovizCinsi
         , guest_country UlkeKodu
         , guest_country UlkeAdi
         , market_code Pazar
         , RoomType KonumOda
         , BookedRoomType KonumFiyat
         , Rez_Durumu
         , GirisGunu
         , insert_date KayitTarihi
         , cancellation_date IptalTarihi
         , room_revenue * exchange_rate OdaGeliriDVZ
         , payment_method OdemeTipi
         , '-' AcentaGrubu
         , acc_code MuhHesapKodu
         , acc_code2 MuhHesapKodu2
    FROM pv_marriott_resv_dtl dtl
