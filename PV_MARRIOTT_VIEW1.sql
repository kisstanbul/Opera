CREATE VIEW PV_MARRIOTT_VIEW1 AS
    SELECT resv_name_id RezNo
         , Type_ "Type"
         , resort HotelNo
         , resort_name Hotel
         , '-' AcentaGrup
         , market_code Pazar
         , travel_agent Acenta
         , guest_country UlkeKodu
         , RoomType OdaTipi
         , arrival_date TarihGiris
         , departure_date - arrival_date Geceleme
         , no_rooms Room
         , adults Yetiskin
         , PaidChild CocukUcretli
         , FreeChild CocukUcretsiz
         , Baby Bebek
         , ROUND ( room_revenue * eur_exchange_rate, 2) OdaGeliriEUR
    FROM pv_marriott_resv_dtl dtl
    WHERE dtl.reservation_date = (SELECT business_date
                                  FROM businessdate b
                                  WHERE b.state = 'OPEN' AND b.resort = dtl.resort)
