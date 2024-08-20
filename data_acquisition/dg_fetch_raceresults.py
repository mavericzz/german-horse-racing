#import calendar
import csv
import requests
from bs4 import BeautifulSoup
from bs4 import re


def get_race_links(url, headers):
    global race_links
    race_links = []
    response = requests.get(url, headers = headers)
    html = response.text
    bsObj = BeautifulSoup(html, 'html.parser')
    race_url_p1 = "https://www.deutscher-galopp.de"
    for link in bsObj.findAll(
        "a", 
        {"class":"tooltip"}, 
        href = re.compile(r'(\/gr\/renntage\/rennen.php)') 
     ):
        if link.attrs['href'] is not None:
            race_url_p2 = re.sub("&d.*", "", link.attrs['href'])
            race_links.append(race_url_p1 + race_url_p2)
    return race_links


def get_race_results(url, headers):
    response = requests.get(url, headers = headers)
    html = response.text
    bsObj = BeautifulSoup(html, 'html.parser')
    gr_raceid = re.search(r'id=\d*', url).group()
    gr_raceid = int(gr_raceid[3:])
    try:
        table = bsObj.findAll("table",{"id":"ergebnis"})[0]
    except IndexError as e:
        print(url)
        print(e)
        pass
    rows = table.findAll("tr")
    table = []
    for row in rows[1:-1]:
        table_row = []
        table_row.append(gr_raceid)
        data = row.findAll(['td'])
        pos = data[0].get_text()
        table_row.append(pos)
        horse_name = data[1].get_text()
        table_row.append(horse_name)
        horse_id = data[1].find(['a']).attrs['href']
        horse_id = re.search(r'\d+', horse_id).group()
        table_row.append(horse_id)
        horse_details = data[1].find(['span']).attrs['title']
        table_row.append(horse_details)
        abstammung = re.search("^[^<]*", horse_details).group()
        table_row.append(abstammung)
        geschlecht = re.search("Geschlecht:[^<]*", horse_details).group()
        table_row.append(geschlecht)
        alter = re.search("Alter[^(]*", horse_details).group()
        table_row.append(alter)
        for i in range(2, len(data)):
            table_row.append(data[i].get_text())
        table.append(table_row)
    with open(csv_file, "a+", newline = '', encoding = 'utf-8') as f:
        writer = csv.writer(f)
        writer.writerows(table)


# mimicking browser
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36'}

# taking input for start date, end date and name of csv-file for output
start_date = input("Start Date (YYYYMMDD)? ")
end_date = input("End Date (YYYYMMDD)? ")
csv_file_input = input("File Name? ")
csv_file = csv_file_input + ".csv"
errors_file = "errors_" + csv_file_input + ".csv"
# build variables from input to concatenate to url later
start_year = start_date[0:4]
start_month = start_date[4:6]
start_day = start_date[6:8]
end_year = end_date[0:4]
end_month = end_date[4:6]
end_day = end_date[6:8]
# dictionary with german months
ger_months = {
    1: 'Januar', 2: 'Februar', 3: 'März', 4: 'April',
    5: 'Mai', 6: 'Juni', 7: 'Juli', 8: 'August',
    9: 'September', 10: 'Oktober', 11: 'November', 12: 'Dezember'
}
# string concatenation for getting the right url (start date to end date)
url = (
    "https://www.deutscher-galopp.de/gr/renntage/rennkalender.php?" +
    "jahr=" + start_year + "&land=8&art=&von=" + start_day + ".+" + 
    ger_months[int(start_month)] + "+" + start_year + "&von_submit=" +
    start_year + "%2F" + start_month + "%2F" + start_day + 
    "&ort=&laengevon=1000&laengebis=6800" +
    "&bis=" + end_day + ".+" + ger_months[int(end_month)] + 
    "+" + end_year + "&bis_submit=" + end_year + "%2F" + end_month + "%2F" +
    end_day
)

race_links = get_race_links(url, headers)

for race_link in race_links:
    try:
        get_race_results(race_link, headers)
    except UnboundLocalError:
        with open(errors_file, 'a+', newline = '') as e_out:
            csvout = csv.writer(e_out)
            csvout.writerow([race_link])
        continue



