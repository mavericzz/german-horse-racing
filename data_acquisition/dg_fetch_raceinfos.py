
import csv
import requests
from bs4 import BeautifulSoup
from bs4 import re
from datetime import datetime

def get_race_info(url, headers):
    """
    

    Parameters
    ----------
    url : TYPE
        DESCRIPTION.

    Returns
    -------
    race_info_dict : TYPE
        DESCRIPTION.

    """
    response = requests.get(url, headers = headers)
    html = response.text
    bsObj = BeautifulSoup(html, 'html.parser')
    # gr_raceid
    gr_raceid = re.search(r'id=\d*', url).group()
    gr_raceid = int(gr_raceid[3:])
    # gr_course: the name of the course on german-racing.com
    gr_course = bsObj.find("span", {"class":"uppercase racetrack"}).get_text()
    # name of the race
    race_name = bsObj.find("span", {"class":"racetitle"}).get_text()
    # gr_title
    gr_title = bsObj.title.get_text()
    # number of the race on the card
    race_no = bsObj.find("span", {"class":"pageNaviCurrent"}).get_text()
    # date and time of the race
    date_time = bsObj.find("span", {"class":"startzeit"}).get_text()
    date_time = str(datetime.strptime(date_time, '%d.%m.%Y, %H:%M'))
    # header-right (race-facts-container) mit Rennklasse, Länge und Preisgeld
    # und Boden. Bei älteren Rennen wurde die Rennklasse nicht angegeben und 
    # header-right
    # enthält statt drei zwei Elemente
    header_right = bsObj.select(
        'div.header-right-container.container-racefacts span'
    )
    race_facts_hr = []
    for item in header_right:
        race_facts_hr.append(item.get_text())
    race_length_idx = [
        i for i, item in enumerate(race_facts_hr) if item.endswith(' m')
        ]
    if len(race_facts_hr) == 2 and race_length_idx[0] == 0:
        race_type = ""
        race_length = race_facts_hr[0].replace(" m", "")
        race_length = float(race_length.replace(".", ""))
        prizemoney_cent = race_facts_hr[1]
        prizemoney_cent = prizemoney_cent[:len(prizemoney_cent)-2]
        prizemoney_cent = int(prizemoney_cent.replace(".", "")) * 100
        going = ""
    elif len(race_facts_hr) == 3 and race_length_idx[0] == 0:
        race_type = ""
        race_length = race_facts_hr[0].replace(" m", "")
        race_length = float(race_length.replace(".", ""))
        prizemoney_cent = race_facts_hr[1]
        prizemoney_cent = prizemoney_cent[:len(prizemoney_cent)-2]
        prizemoney_cent = int(prizemoney_cent.replace(".", "")) * 100
        going = race_facts_hr[2]
    elif len(race_facts_hr) == 3 and race_length_idx[0] == 1:
        race_type = race_facts_hr[0]
        race_length = race_facts_hr[1].replace(" m", "")
        race_length = float(race_length.replace(".", ""))
        prizemoney_cent = race_facts_hr[2]
        prizemoney_cent = prizemoney_cent[:len(prizemoney_cent)-2]
        prizemoney_cent = int(prizemoney_cent.replace(".", "")) * 100
        going = ""
    else:
        race_type = race_facts_hr[0]
        race_length = race_facts_hr[1].replace(" m", "")
        race_length = float(race_length.replace(".", ""))
        prizemoney_cent = race_facts_hr[2]
        prizemoney_cent = prizemoney_cent[:len(prizemoney_cent)-2]
        prizemoney_cent = int(prizemoney_cent.replace(".", "")) * 100
        going = race_facts_hr[3]
    # race description
    description = bsObj.find(
        'div', {'class':'elementStandard elementText elementText_var2'}
    ).contents[7]
    # additional info: facts
    facts = bsObj.findAll("tfoot")[0].td.get_text()
    # race_time_secs
    try:
        race_time = re.findall(r"ZEIT DES RENNENS: [0-9\:\,]*", facts)[0]
        race_time = re.sub("ZEIT DES RENNENS: ", "", race_time)
        if race_time.find(":"):
            rt_mins = int(re.sub(r":.*$", "", race_time))
            rt_secs = re.sub(r"^.*:", "", race_time)
            rt_secs = float(re.sub(r"\,", ".", rt_secs))
            race_time_secs = round(rt_mins * 60 + rt_secs, 2)
        else:
            race_time_secs = round(float(re.sub(r"\,", ".", race_time)), 2)
    except IndexError:
        race_time_secs = ""
    # Zweierwette
    try:
        zw = re.sub(r"^.*Zweierwette ", "", facts)
        zw = re.sub(r" .*", "", zw)
        zw = re.sub(r"\.", "", zw)
        zw = float(re.sub(r"\,", ".", zw))
    except ValueError:
        zw = ""
    # Dreierwette
    try:
        dw = re.sub(r"^.*Dreierwette ", "", facts)
        dw = re.sub(r"[ A-Z].*", "", dw)
        dw = re.sub(r"\.", "", dw)
        comma_index = dw.index(",")
        #dw = re.search('^\d*,\d', dw).group()
        dw = dw[:comma_index + 2]
        dw = float(re.sub(r",", ".", dw))
    except ValueError:
        dw = ""
    # Viererwette
    vw = re.findall(r"Viererwette [0-9\,\.]*", facts)
    if len(vw) > 0:
        vw = vw[0]
        vw = re.sub(r"[ A-Za-z]*", "", vw)
        vw = re.sub(r"\.", "", vw)
        vw = re.search(r'^\d*,\d*', vw).group()
        vw = float(re.sub(r",", ".", vw))
    else:
        vw = ""
    race_info_vars = [
        'gr_raceid', 'gr_course', 'race_name', 'gr_title', 'race_no', 
        'date_time', 'race_type', 'race_length', 'prizemoney_cent', 'going', 
        'description', 'facts', 'race_time_secs', 'zw', 'dw', 'vw'
    ]
    scope = locals()
    race_info_dict = dict((k, eval(k, scope)) for k in race_info_vars)
    return race_info_dict



    

def get_race_links(url, headers):
    """

    Parameters
    ----------
    url : string
        Link zu den Veranstaltungen (Renntage) für ausgewählten Zeitraum.

    Returns
    -------
    race_links : list
        Liste mit Links zu den einzelnen Rennen innerhalb des ausgewählten Zeitraums.

    """
    global race_links
    race_links = []
    response = requests.get(url, headers = headers)
    html = response.text
    bsObj = BeautifulSoup(html, 'html.parser')
    race_url_p1 = "https://www.deutscher-galopp.de"
    for link in bsObj.findAll(
        "a", 
        {"class":"tooltip"}, 
        href = re.compile("(\/gr\/renntage\/rennen.php)") 
     ):
        if link.attrs['href'] is not None:
            race_url_p2 = re.sub("&d.*", "", link.attrs['href'])
            race_links.append(race_url_p1 + race_url_p2)
    return race_links




def get_veranstaltungen(
        start_year, start_month, start_day, end_year, end_month, end_day
    ):
    """
    Constructs a URL for the deutscher-galopp.de website based on a specified
    date range.
    
    Args:
        start_year (str): Starting year (YYYY format).
        start_month (str): Starting month (MM format).
        start_day (str): Starting day (DD format).
        end_year (str): Ending year (YYYY format).
        end_month (str): Ending month (MM format).
        end_day (str): Ending day (DD format).
    
    Returns:
        str: The URL for deutscher-galopp.de with the specified date range.
    """
    
    german_months = {
        1: 'Januar', 2: 'Februar', 3: 'März', 4: 'April',
        5: 'Mai', 6: 'Juni', 7: 'Juli', 8: 'August',
        9: 'September', 10: 'Oktober', 11: 'November', 12: 'Dezember'
    }
    start_month_str = german_months[int(start_month)]
    end_month_str = german_months[int(end_month)]
    url_format = f"""
        https://www.deutscher-galopp.de/gr/renntage/rennkalender.php?
        jahr={start_year}&land=8&art=&von={start_day}.+{start_month_str}+
        {start_year}&von_submit={start_year}%2F{start_month}%2F{start_day} 
        &ort=&laengevon=1000&laengebis=6800&bis={end_day}.+{end_month_str} 
        +{end_year}&bis_submit={end_year}%2F{end_month}%2F{end_day}
        """
    return url_format


# Mimicking browser
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36'}

# taking input for start date, end date and name of csv-file for output
start_date = input("Start Date (YYYYMMDD)? ")
end_date = input("End Date (YYYYMMDD)? ")
start_year = start_date[0:4]
start_month = start_date[4:6]
start_day = start_date[6:8]
end_year = end_date[0:4]
end_month = end_date[4:6]
end_day = end_date[6:8]

csv_file_input = input("File Name? ")
csv_file = csv_file_input + ".csv"
errors_file = "errors_" + csv_file_input + ".csv"


veranstaltungen = get_veranstaltungen(
    start_year, start_month, start_day, end_year, end_month, end_day
)
race_links = get_race_links(veranstaltungen, headers)
print(race_links)

race_info_list = []

for race_link in race_links:
    try:
        print(race_link)
        race_info = get_race_info(race_link, headers)
        race_info_list.append(race_info)
    except (AttributeError, ValueError):
        with open(errors_file, 'a+', newline = '') as e_out:
            csvout = csv.writer(e_out)
            csvout.writerow([race_link])
        continue

race_info_keys = race_info_list[0].keys()
with open(csv_file, 'w', newline = '', encoding = 'utf-8') as fout:
    dict_writer = csv.DictWriter(fout, race_info_keys)
    dict_writer.writerows(race_info_list)

