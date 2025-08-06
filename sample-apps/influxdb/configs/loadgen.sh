#!/bin/bash

# Create a config
influx config create --config-name sample-config --host-url http://influxdb-influxdb2.influxdb.svc.cluster.local:80 --org influxdata --token nrlukwAn13XLMIlYeDTg7g47T28cEG4P --active

# Create buckets
influx bucket create --name loadgen-0
influx bucket create --name loadgen-1

# Writing data to buckets
if [ -f /influxdb2-sample-data/air-sensor-data/air-sensor-data.lp ]; then
    influx write --bucket loadgen-0 --file /influxdb2-sample-data/air-sensor-data/air-sensor-data.lp
else
    echo "temperature,location=room1 value=22.5 $(date +%s)000000000" | influx write --bucket loadgen-0 -
fi

if [ -f /influxdb2-sample-data/bitcoin-price-data/currentprice.lp ]; then
    influx write --bucket loadgen-1 --file /influxdb2-sample-data/bitcoin-price-data/currentprice.lp
else
    echo "bitcoin,currency=USD price=45000.0 $(date +%s)000000000" | influx write --bucket loadgen-1 -
fi

if [ -f /influxdb2-sample-data/noaa-ndbc-data/latest-observations.lp ]; then
    influx write --bucket loadgen-0 --file /influxdb2-sample-data/noaa-ndbc-data/latest-observations.lp
else
    echo "weather,location=buoy1 wind_speed=15.2 $(date +%s)000000000" | influx write --bucket loadgen-0 -
fi

if [ -f /influxdb2-sample-data/usgs-earthquake-data/all_week.lp ]; then
    influx write --bucket loadgen-1 --file /influxdb2-sample-data/usgs-earthquake-data/all_week.lp
else
    echo "earthquake,location=california magnitude=3.2 $(date +%s)000000000" | influx write --bucket loadgen-1 -
fi

# Query data from buckets for 15s
end=$((SECONDS+15))
while [ $SECONDS -lt $end ]
do
    influx query 'from(bucket:"loadgen-0") |> range(start:-1h)'
    influx query 'from(bucket:"loadgen-1") |> range(start:-1h)'
done

# Delete buckets
influx bucket delete --name loadgen-0
influx bucket delete --name loadgen-1
