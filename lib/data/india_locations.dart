/// Structured dataset of Indian States, Districts, and Cities for hierarchical
/// location selection in Resumer.
class IndianDistrict {
  final String name;
  final List<String> cities;

  const IndianDistrict({
    required this.name,
    required this.cities,
  });
}

class IndianState {
  final String name;
  final List<IndianDistrict> districts;

  const IndianState({
    required this.name,
    required this.districts,
  });

  List<String> get allCities {
    final list = <String>[];
    for (final d in districts) {
      list.addAll(d.cities);
    }
    return list;
  }
}

class LocationSearchResult {
  final String title;
  final String subtitle;
  final String formattedLocation;
  final String type; // 'city', 'district', 'state'

  const LocationSearchResult({
    required this.title,
    required this.subtitle,
    required this.formattedLocation,
    required this.type,
  });
}

class IndianLocationData {
  static const List<IndianState> states = [
    IndianState(
      name: 'Karnataka',
      districts: [
        IndianDistrict(
          name: 'Bengaluru Urban',
          cities: [
            'Bengaluru',
            'Electronic City',
            'Whitefield',
            'Koramangala',
            'HSR Layout',
            'Indiranagar',
            'Marathahalli',
            'Yelahanka',
            'Jayanagar',
            'Hebbal',
            'Bellandur',
            'Bannerghatta Road',
          ],
        ),
        IndianDistrict(
          name: 'Bengaluru Rural',
          cities: ['Devanahalli', 'Nelamangala', 'Doddaballapura', 'Hoskote'],
        ),
        IndianDistrict(
          name: 'Mysuru',
          cities: ['Mysuru', 'Nanjangud', 'Hunsur', 'Hebbal Industrial Area'],
        ),
        IndianDistrict(
          name: 'Dakshina Kannada',
          cities: ['Mangaluru', 'Surathkal', 'Bantwal', 'Puttur'],
        ),
        IndianDistrict(
          name: 'Dharwad',
          cities: ['Hubballi', 'Dharwad'],
        ),
        IndianDistrict(
          name: 'Belagavi',
          cities: ['Belagavi', 'Gokak', 'Chikkodi'],
        ),
        IndianDistrict(
          name: 'Tumakuru',
          cities: ['Tumakuru', 'Tiptur', 'Vasanthanarasapura'],
        ),
        IndianDistrict(
          name: 'Udupi',
          cities: ['Udupi', 'Manipal', 'Kundapura', 'Karkala'],
        ),
        IndianDistrict(
          name: 'Shivamogga',
          cities: ['Shivamogga', 'Bhadravati', 'Sagar'],
        ),
        IndianDistrict(
          name: 'Kalaburagi',
          cities: ['Kalaburagi', 'Sedam', 'Aland'],
        ),
        IndianDistrict(
          name: 'Ballari',
          cities: ['Ballari', 'Sandur', 'Siruguppa'],
        ),
        IndianDistrict(
          name: 'Hassan',
          cities: ['Hassan', 'Arsikere', 'Channarayapatna'],
        ),
        IndianDistrict(
          name: 'Mandya',
          cities: ['Mandya', 'Maddur', 'Srirangapatna'],
        ),
        IndianDistrict(
          name: 'Davanagere',
          cities: ['Davanagere', 'Harihar'],
        ),
        IndianDistrict(
          name: 'Kolar',
          cities: ['Kolar', 'Malur', 'Bangarapet'],
        ),
        IndianDistrict(
          name: 'Chikkamagaluru',
          cities: ['Chikkamagaluru', 'Kadur', 'Tarikere'],
        ),
        IndianDistrict(
          name: 'Uttara Kannada',
          cities: ['Karwar', 'Sirsi', 'Dandeli', 'Kumta'],
        ),
        IndianDistrict(
          name: 'Kodagu',
          cities: ['Madikeri', 'Kushalnagar', 'Virajpet'],
        ),
        IndianDistrict(
          name: 'Ramanagara',
          cities: ['Ramanagara', 'Channapatna', 'Bidadi Industrial Area'],
        ),
        IndianDistrict(
          name: 'Chitradurga',
          cities: ['Chitradurga', 'Challakere', 'Hiriyur'],
        ),
        IndianDistrict(
          name: 'Bagalkot',
          cities: ['Bagalkot', 'Ilkal', 'Jamkhandi'],
        ),
        IndianDistrict(
          name: 'Vijayapura',
          cities: ['Vijayapura', 'Basavana Bagewadi', 'Sindgi'],
        ),
        IndianDistrict(
          name: 'Bidar',
          cities: ['Bidar', 'Basavakalyan', 'Humnabad'],
        ),
        IndianDistrict(
          name: 'Raichur',
          cities: ['Raichur', 'Sindhanur', 'Manvi'],
        ),
        IndianDistrict(
          name: 'Koppal',
          cities: ['Koppal', 'Gangavathi', 'Kushtagi'],
        ),
        IndianDistrict(
          name: 'Gadag',
          cities: ['Gadag', 'Betageri', 'Nargund'],
        ),
        IndianDistrict(
          name: 'Haveri',
          cities: ['Haveri', 'Ranebennur', 'Byadgi'],
        ),
        IndianDistrict(
          name: 'Yadgir',
          cities: ['Yadgir', 'Shorapur', 'Shahapur'],
        ),
        IndianDistrict(
          name: 'Chamarajanagar',
          cities: ['Chamarajanagar', 'Kollegal', 'Gundlupet'],
        ),
        IndianDistrict(
          name: 'Chikkaballapur',
          cities: ['Chikkaballapur', 'Gauribidanur', 'Sidlaghatta'],
        ),
      ],
    ),
    IndianState(
      name: 'Maharashtra',
      districts: [
        IndianDistrict(
          name: 'Mumbai City',
          cities: [
            'Mumbai',
            'South Mumbai',
            'Nariman Point',
            'Fort',
            'Colaba',
            'Lower Parel',
            'Worli',
          ],
        ),
        IndianDistrict(
          name: 'Mumbai Suburban',
          cities: [
            'Andheri',
            'Bandra',
            'BKC (Bandra Kurla Complex)',
            'Powai',
            'Borivali',
            'Goregaon',
            'Malad',
            'Kurla',
            'Ghatkopar',
            'Vile Parle',
            'Kandivali',
          ],
        ),
        IndianDistrict(
          name: 'Pune',
          cities: [
            'Pune',
            'Hinjewadi IT Park',
            'Pimpri-Chinchwad',
            'Hadapsar',
            'Magarpatta City',
            'Kharadi IT SEZ',
            'Baner',
            'Viman Nagar',
            'Kalyani Nagar',
            'Chakan Industrial Area',
            'Bhosari',
            'Talawade IT Park',
          ],
        ),
        IndianDistrict(
          name: 'Thane',
          cities: [
            'Thane',
            'Navi Mumbai (Airoli / Ghansoli)',
            'Kalyan',
            'Dombivli',
            'Mira-Bhayandar',
            'Ulhasnagar',
            'Bhiwandi',
          ],
        ),
        IndianDistrict(
          name: 'Raigad',
          cities: [
            'Navi Mumbai (Vashi / Nerul / Belapur)',
            'Panvel',
            'Kharghar',
            'Taloja MIDC',
            'Alibag',
            'Khopoli',
          ],
        ),
        IndianDistrict(
          name: 'Nagpur',
          cities: ['Nagpur', 'MIHAN SEZ', 'Kamptee', 'Hingna MIDC', 'Butibori'],
        ),
        IndianDistrict(
          name: 'Nashik',
          cities: ['Nashik', 'Ambad MIDC', 'Satpur MIDC', 'Malegaon', 'Sinnar'],
        ),
        IndianDistrict(
          name: 'Chhatrapati Sambhajinagar',
          cities: [
            'Chhatrapati Sambhajinagar (Aurangabad)',
            'Shendra MIDC',
            'Waluj MIDC',
            'Chikhalthana',
          ],
        ),
        IndianDistrict(
          name: 'Kolhapur',
          cities: [
            'Kolhapur',
            'Ichalkaranji',
            'Shiroli MIDC',
            'Gokul Shirgaon'
          ],
        ),
        IndianDistrict(
          name: 'Solapur',
          cities: ['Solapur', 'Pandharpur', 'Barshi'],
        ),
        IndianDistrict(
          name: 'Palghar',
          cities: ['Vasai', 'Virar', 'Palghar', 'Tarapur MIDC', 'Boisar'],
        ),
        IndianDistrict(
          name: 'Satara',
          cities: ['Satara', 'Karad', 'Wai'],
        ),
        IndianDistrict(
          name: 'Sangli',
          cities: ['Sangli', 'Miraj', 'Kupwad'],
        ),
        IndianDistrict(
          name: 'Ahmednagar',
          cities: ['Ahmednagar', 'Shirdi', 'Sangamner'],
        ),
        IndianDistrict(
          name: 'Jalgaon',
          cities: ['Jalgaon', 'Bhusawal', 'Chalisgaon'],
        ),
        IndianDistrict(
          name: 'Amravati',
          cities: ['Amravati', 'Achalpur', 'Badnera'],
        ),
        IndianDistrict(
          name: 'Akola',
          cities: ['Akola', 'Akot', 'Murtizapur'],
        ),
        IndianDistrict(
          name: 'Nanded',
          cities: ['Nanded', 'Mukhed', 'Degloor'],
        ),
        IndianDistrict(
          name: 'Latur',
          cities: ['Latur', 'Udgir', 'Ausa'],
        ),
        IndianDistrict(
          name: 'Dhule',
          cities: ['Dhule', 'Shirpur', 'Dondaicha'],
        ),
        IndianDistrict(
          name: 'Chandrapur',
          cities: ['Chandrapur', 'Ballarpur', 'Warora'],
        ),
        IndianDistrict(
          name: 'Ratnagiri',
          cities: ['Ratnagiri', 'Chiplun', 'Khed'],
        ),
        IndianDistrict(
          name: 'Sindhudurg',
          cities: ['Sawantwadi', 'Kankavli', 'Malvan'],
        ),
      ],
    ),
    IndianState(
      name: 'Telangana',
      districts: [
        IndianDistrict(
          name: 'Hyderabad',
          cities: [
            'Hyderabad',
            'HITEC City',
            'Gachibowli',
            'Madhapur',
            'Banjara Hills',
            'Jubilee Hills',
            'Kondapur',
            'Begumpet',
            'Ameerpet',
            'Somajiguda',
            'Abids',
          ],
        ),
        IndianDistrict(
          name: 'Rangareddy',
          cities: [
            'Financial District',
            'Nanakramguda',
            'Kokapet',
            'Manikonda',
            'Shamshabad',
            'Rajendranagar',
            'Maheshwaram',
            'Adibatla Aerospace SEZ',
          ],
        ),
        IndianDistrict(
          name: 'Medchal-Malkajgiri',
          cities: [
            'Secunderabad',
            'Uppal IT SEZ',
            'Malkajgiri',
            'Kompally',
            'Medchal',
            'Kukatpally',
            'Alwal',
            'Pocharam',
          ],
        ),
        IndianDistrict(
          name: 'Sangareddy',
          cities: [
            'IIT Hyderabad / Kandi',
            'Patancheru Industrial Area',
            'Beeramguda',
            'Sangareddy',
            'Ameenpur',
          ],
        ),
        IndianDistrict(
          name: 'Hanumakonda',
          cities: ['Warangal', 'Hanumakonda', 'Kazipet'],
        ),
        IndianDistrict(
          name: 'Karimnagar',
          cities: ['Karimnagar', 'Ramagundam', 'Godavarikhani'],
        ),
        IndianDistrict(
          name: 'Nizamabad',
          cities: ['Nizamabad', 'Bodhan', 'Armoor'],
        ),
        IndianDistrict(
          name: 'Khammam',
          cities: ['Khammam', 'Kothagudem', 'Sathupally'],
        ),
        IndianDistrict(
          name: 'Nalgonda',
          cities: ['Nalgonda', 'Miryalaguda', 'Suryapet'],
        ),
        IndianDistrict(
          name: 'Mahabubnagar',
          cities: ['Mahabubnagar', 'Jadcherla IT / Pharma SEZ', 'Badepally'],
        ),
        IndianDistrict(
          name: 'Siddipet',
          cities: ['Siddipet', 'Gajwel', 'Husnabad'],
        ),
        IndianDistrict(
          name: 'Mancherial',
          cities: ['Mancherial', 'Bellampalli', 'Mandamarri'],
        ),
      ],
    ),
    IndianState(
      name: 'Delhi NCR',
      districts: [
        IndianDistrict(
          name: 'Central Delhi',
          cities: ['Connaught Place', 'Karol Bagh', 'Paharganj', 'Daryaganj'],
        ),
        IndianDistrict(
          name: 'New Delhi',
          cities: [
            'New Delhi',
            'Barakhamba Road',
            'Chanakyapuri',
            'Lodhi Road'
          ],
        ),
        IndianDistrict(
          name: 'South Delhi',
          cities: [
            'Saket',
            'Hauz Khas',
            'Nehru Place',
            'Greater Kailash',
            'Lajpat Nagar',
            'Okhla Industrial Area',
            'Kalkaji',
          ],
        ),
        IndianDistrict(
          name: 'South West Delhi',
          cities: ['Dwarka', 'Vasant Kunj', 'Delhi Aerocity', 'Mahipalpur'],
        ),
        IndianDistrict(
          name: 'North Delhi',
          cities: ['Civil Lines', 'Model Town', 'Pitampura', 'Rohini'],
        ),
        IndianDistrict(
          name: 'West Delhi',
          cities: [
            'Janakpuri',
            'Rajouri Garden',
            'Punjabi Bagh',
            'Paschim Vihar'
          ],
        ),
        IndianDistrict(
          name: 'East Delhi',
          cities: ['Laxmi Nagar', 'Mayur Vihar', 'Preet Vihar', 'Patparganj'],
        ),
        IndianDistrict(
          name: 'Gurugram (NCR)',
          cities: [
            'Gurugram',
            'Cyber City',
            'DLF Cyber Hub',
            'Golf Course Road',
            'Golf Course Extension',
            'Sohna Road',
            'Udyog Vihar',
            'Manesar Industrial Hub',
            'Sector 44 IT Hub',
          ],
        ),
        IndianDistrict(
          name: 'Gautam Buddha Nagar (NCR)',
          cities: [
            'Noida',
            'Sector 62 IT Park',
            'Sector 125/126 Expressway',
            'Sector 18',
            'Greater Noida',
            'Knowledge Park',
            'Pari Chowk',
          ],
        ),
        IndianDistrict(
          name: 'Faridabad (NCR)',
          cities: ['Faridabad', 'NIT Faridabad', 'Ballabhgarh', 'Sector 15'],
        ),
        IndianDistrict(
          name: 'Ghaziabad (NCR)',
          cities: [
            'Ghaziabad',
            'Indirapuram',
            'Vaishali',
            'Kaushambi',
            'Sahibabad'
          ],
        ),
      ],
    ),
    IndianState(
      name: 'Tamil Nadu',
      districts: [
        IndianDistrict(
          name: 'Chennai',
          cities: [
            'Chennai',
            'OMR (IT Corridor)',
            'T. Nagar',
            'Guindy Industrial Estate',
            'Adyar',
            'Velachery',
            'Perungudi',
            'Sholinganallur',
            'Anna Nagar',
            'Taramani (TICEL / Ascendas)',
            'Nungambakkam',
          ],
        ),
        IndianDistrict(
          name: 'Chengalpattu',
          cities: [
            'Mahindra World City',
            'Tambaram',
            'Chengalpattu',
            'Kelambakkam',
            'Navalur',
            'Siruseri SIPCOT IT Park',
            'Guduvanchery',
          ],
        ),
        IndianDistrict(
          name: 'Kanchipuram',
          cities: [
            'Sriperumbudur Industrial Hub',
            'Oragadam SIPCOT',
            'Kanchipuram'
          ],
        ),
        IndianDistrict(
          name: 'Tiruvallur',
          cities: [
            'Ambattur Industrial Estate',
            'Tiruvallur',
            'Avadi',
            'Gummidipoondi SIPCOT'
          ],
        ),
        IndianDistrict(
          name: 'Coimbatore',
          cities: [
            'Coimbatore',
            'TIDEL Park Coimbatore',
            'Peelamedu',
            'Gandhipuram',
            'Saravanampatti IT SEZ',
            'Pollachi',
          ],
        ),
        IndianDistrict(
          name: 'Madurai',
          cities: ['Madurai', 'ELCOT IT Park Madurai', 'Koodal Nagar'],
        ),
        IndianDistrict(
          name: 'Tiruchirappalli',
          cities: [
            'Tiruchirappalli',
            'NIT Trichy Area',
            'Thuvakudi Industrial Area'
          ],
        ),
        IndianDistrict(
          name: 'Salem',
          cities: ['Salem', 'Steel Plant Area', 'Attur'],
        ),
        IndianDistrict(
          name: 'Tiruppur',
          cities: ['Tiruppur', 'Avinashi', 'Palladam'],
        ),
        IndianDistrict(
          name: 'Erode',
          cities: ['Erode', 'Perundurai SIPCOT', 'Gobichettipalayam'],
        ),
        IndianDistrict(
          name: 'Vellore',
          cities: ['Vellore', 'Katpadi', 'Ranipet SIPCOT'],
        ),
        IndianDistrict(
          name: 'Krishnagiri',
          cities: ['Hosur', 'Hosur SIPCOT IT Park', 'Krishnagiri'],
        ),
        IndianDistrict(
          name: 'Tirunelveli',
          cities: ['Tirunelveli', 'Gangaikondan IT Park', 'Palayamkottai'],
        ),
        IndianDistrict(
          name: 'Thoothukudi',
          cities: ['Thoothukudi', 'Kovilpatti'],
        ),
        IndianDistrict(
          name: 'Thanjavur',
          cities: ['Thanjavur', 'Kumbakonam'],
        ),
        IndianDistrict(
          name: 'Dindigul',
          cities: ['Dindigul', 'Palani', 'Kodaikanal'],
        ),
      ],
    ),
    IndianState(
      name: 'Gujarat',
      districts: [
        IndianDistrict(
          name: 'Ahmedabad',
          cities: [
            'Ahmedabad',
            'SG Highway',
            'Prahlad Nagar',
            'Bopal',
            'Sanand GIDC',
            'Navrangpura',
            'Satellite',
            'Changodar',
          ],
        ),
        IndianDistrict(
          name: 'Gandhinagar',
          cities: [
            'Gandhinagar',
            'GIFT City',
            'Infocity Gandhinagar',
            'Koba',
            'Sector 10',
          ],
        ),
        IndianDistrict(
          name: 'Surat',
          cities: [
            'Surat',
            'Hazira Industrial Belt',
            'Adajan',
            'Vesu',
            'Sachin GIDC'
          ],
        ),
        IndianDistrict(
          name: 'Vadodara',
          cities: [
            'Vadodara',
            'Alkapuri',
            'Makarpura GIDC',
            'Manjusar GIDC',
            'Gorwa'
          ],
        ),
        IndianDistrict(
          name: 'Rajkot',
          cities: ['Rajkot', 'Metoda GIDC', 'Shapar-Veraval', 'Kalawad Road'],
        ),
        IndianDistrict(
          name: 'Bhavnagar',
          cities: ['Bhavnagar', 'Alang', 'Sihor'],
        ),
        IndianDistrict(
          name: 'Jamnagar',
          cities: ['Jamnagar', 'Reliance Complex / Moti Khavdi', 'Dared GIDC'],
        ),
        IndianDistrict(
          name: 'Bharuch',
          cities: ['Bharuch', 'Ankleshwar GIDC', 'Dahej Petroleum SEZ'],
        ),
        IndianDistrict(
          name: 'Anand',
          cities: ['Anand', 'Vallabh Vidyanagar', 'Vithal Udyognagar GIDC'],
        ),
        IndianDistrict(
          name: 'Valsad',
          cities: ['Vapi GIDC', 'Valsad', 'Umbergaon GIDC'],
        ),
        IndianDistrict(
          name: 'Kutch',
          cities: ['Gandhidham', 'Mundra Port SEZ', 'Bhuj', 'Anjar'],
        ),
        IndianDistrict(
          name: 'Morbi',
          cities: ['Morbi', 'Wankaner'],
        ),
      ],
    ),
    IndianState(
      name: 'West Bengal',
      districts: [
        IndianDistrict(
          name: 'Kolkata',
          cities: [
            'Kolkata',
            'Park Street',
            'Ballygunge',
            'Alipore',
            'Dalhousie',
            'Esplanade',
            'Jadavpur',
          ],
        ),
        IndianDistrict(
          name: 'North 24 Parganas',
          cities: [
            'Salt Lake (Sector V IT Hub)',
            'New Town (Action Area I-III)',
            'Rajarhat',
            'Dum Dum',
            'Barasat',
          ],
        ),
        IndianDistrict(
          name: 'Howrah',
          cities: ['Howrah', 'Bally', 'Shibpur', 'Uluberia Industrial Area'],
        ),
        IndianDistrict(
          name: 'Hooghly',
          cities: ['Serampore', 'Chandannagar', 'Uttarpara', 'Dankuni'],
        ),
        IndianDistrict(
          name: 'Darjeeling',
          cities: ['Siliguri', 'Darjeeling', 'Kurseong'],
        ),
        IndianDistrict(
          name: 'Paschim Bardhaman',
          cities: ['Durgapur', 'Asansol', 'Raniganj'],
        ),
        IndianDistrict(
          name: 'Purba Medinipur',
          cities: ['Haldia Port & Petrochemicals', 'Tamluk', 'Digha'],
        ),
        IndianDistrict(
          name: 'Paschim Medinipur',
          cities: ['Kharagpur', 'IIT Kharagpur Area', 'Midnapore'],
        ),
      ],
    ),
    IndianState(
      name: 'Kerala',
      districts: [
        IndianDistrict(
          name: 'Ernakulam',
          cities: [
            'Kochi',
            'Cochin',
            'Infopark Kakkanad',
            'SmartCity Kochi',
            'Aluva',
            'Edappally',
            'Kaloor',
            'MG Road Kochi',
          ],
        ),
        IndianDistrict(
          name: 'Thiruvananthapuram',
          cities: [
            'Thiruvananthapuram (Trivandrum)',
            'Technopark Phase 1-4',
            'Kazhakkoottam',
            'Kowdiar',
            'Vellayambalam',
          ],
        ),
        IndianDistrict(
          name: 'Kozhikode',
          cities: ['Kozhikode (Calicut)', 'Cyberpark Kozhikode', 'Mavoor Road'],
        ),
        IndianDistrict(
          name: 'Thrissur',
          cities: ['Thrissur', 'Koratty Infopark', 'Chalakudy'],
        ),
        IndianDistrict(
          name: 'Kannur',
          cities: ['Kannur', 'Thalassery', 'Payyanur'],
        ),
        IndianDistrict(
          name: 'Kottayam',
          cities: ['Kottayam', 'Changanassery', 'Pala'],
        ),
        IndianDistrict(
          name: 'Kollam',
          cities: ['Kollam', 'Kollam Technopark', 'Karunagappally'],
        ),
        IndianDistrict(
          name: 'Palakkad',
          cities: ['Palakkad', 'Kinfra Park Kanjikode', 'Ottapalam'],
        ),
        IndianDistrict(
          name: 'Malappuram',
          cities: ['Malappuram', 'Manjeri', 'Perinthalmanna'],
        ),
        IndianDistrict(
          name: 'Alappuzha',
          cities: ['Alappuzha', 'Cherthala Infopark', 'Kayamkulam'],
        ),
      ],
    ),
    IndianState(
      name: 'Andhra Pradesh',
      districts: [
        IndianDistrict(
          name: 'Visakhapatnam',
          cities: [
            'Visakhapatnam (Vizag)',
            'Madhurawada IT SEZ',
            'Rushikonda IT Park',
            'Gajuwaka',
            'Dwaraka Nagar',
            'Anakapalle',
          ],
        ),
        IndianDistrict(
          name: 'NTR (Vijayawada)',
          cities: [
            'Vijayawada',
            'Benz Circle',
            'Ibrahimpatnam',
            'Gannavaram IT Park'
          ],
        ),
        IndianDistrict(
          name: 'Guntur',
          cities: ['Guntur', 'Mangalagiri IT SEZ', 'Amaravati', 'Tenali'],
        ),
        IndianDistrict(
          name: 'Tirupati',
          cities: ['Tirupati', 'Sri City SEZ', 'Renigunta Electronics Hub'],
        ),
        IndianDistrict(
          name: 'Kurnool',
          cities: ['Kurnool', 'Nandyal', 'Adoni'],
        ),
        IndianDistrict(
          name: 'Nellore',
          cities: ['Nellore', 'Gudur', 'Kavali'],
        ),
        IndianDistrict(
          name: 'Kakinada',
          cities: ['Kakinada', 'Samalkot', 'Pithapuram'],
        ),
        IndianDistrict(
          name: 'East Godavari',
          cities: ['Rajahmundry', 'Kovvur'],
        ),
        IndianDistrict(
          name: 'Anantapur',
          cities: ['Anantapur', 'Hindupur', 'Dharmavaram'],
        ),
        IndianDistrict(
          name: 'YSR Kadapa',
          cities: ['Kadapa', 'Proddatur', 'Pulivendula'],
        ),
      ],
    ),
    IndianState(
      name: 'Haryana',
      districts: [
        IndianDistrict(
          name: 'Gurugram',
          cities: [
            'Gurugram',
            'Cyber City',
            'Golf Course Road',
            'Sohna Road',
            'Udyog Vihar',
            'Manesar',
          ],
        ),
        IndianDistrict(
          name: 'Faridabad',
          cities: ['Faridabad', 'NIT Faridabad', 'Ballabhgarh'],
        ),
        IndianDistrict(
          name: 'Panchkula',
          cities: ['Panchkula', 'IT Park Panchkula', 'Kalka', 'Pinjore'],
        ),
        IndianDistrict(
          name: 'Ambala',
          cities: ['Ambala Cantt', 'Ambala City'],
        ),
        IndianDistrict(
          name: 'Karnal',
          cities: ['Karnal', 'Gharaunda'],
        ),
        IndianDistrict(
          name: 'Panipat',
          cities: ['Panipat', 'Samalkha'],
        ),
        IndianDistrict(
          name: 'Sonipat',
          cities: ['Sonipat', 'Kundli Industrial Area', 'Rai Industrial Area'],
        ),
        IndianDistrict(
          name: 'Rohtak',
          cities: ['Rohtak', 'IMT Rohtak', 'Meham'],
        ),
        IndianDistrict(
          name: 'Hisar',
          cities: ['Hisar', 'Hansi'],
        ),
      ],
    ),
    IndianState(
      name: 'Punjab',
      districts: [
        IndianDistrict(
          name: 'SAS Nagar (Mohali)',
          cities: [
            'Mohali',
            'QuarkCity IT SEZ',
            'Sector 67 / 74 IT Park',
            'Kharar',
            'Zirakpur',
            'Dera Bassi',
          ],
        ),
        IndianDistrict(
          name: 'Ludhiana',
          cities: ['Ludhiana', 'Ferozepur Road', 'Civil Lines'],
        ),
        IndianDistrict(
          name: 'Amritsar',
          cities: ['Amritsar', 'Ranjit Avenue'],
        ),
        IndianDistrict(
          name: 'Jalandhar',
          cities: ['Jalandhar', 'Model Town', 'Rama Mandi'],
        ),
        IndianDistrict(
          name: 'Patiala',
          cities: ['Patiala', 'Rajpura Industrial Belt'],
        ),
        IndianDistrict(
          name: 'Bathinda',
          cities: ['Bathinda', 'Rampura Phul'],
        ),
      ],
    ),
    IndianState(
      name: 'Rajasthan',
      districts: [
        IndianDistrict(
          name: 'Jaipur',
          cities: [
            'Jaipur',
            'Sitapura Industrial Area',
            'Malviya Nagar',
            'Mansarovar',
            'Vaishali Nagar',
            'Mahindra World City SEZ',
          ],
        ),
        IndianDistrict(
          name: 'Jodhpur',
          cities: ['Jodhpur', 'Basni Industrial Area', 'Ratanada'],
        ),
        IndianDistrict(
          name: 'Udaipur',
          cities: ['Udaipur', 'Sukher Industrial Area', 'Madri'],
        ),
        IndianDistrict(
          name: 'Kota',
          cities: ['Kota', 'Indraprastha Industrial Area'],
        ),
        IndianDistrict(
          name: 'Alwar',
          cities: [
            'Bhiwadi Industrial Area',
            'Neemrana Japanese Zone',
            'Alwar'
          ],
        ),
        IndianDistrict(
          name: 'Ajmer',
          cities: ['Ajmer', 'Kishangarh', 'Beawar'],
        ),
        IndianDistrict(
          name: 'Bikaner',
          cities: ['Bikaner', 'Nokha'],
        ),
      ],
    ),
    IndianState(
      name: 'Uttar Pradesh',
      districts: [
        IndianDistrict(
          name: 'Gautam Buddha Nagar',
          cities: [
            'Noida',
            'Sector 62 IT Park',
            'Sector 125/126 Expressway',
            'Greater Noida',
            'Knowledge Park',
            'Pari Chowk',
          ],
        ),
        IndianDistrict(
          name: 'Ghaziabad',
          cities: [
            'Ghaziabad',
            'Indirapuram',
            'Vaishali',
            'Kaushambi',
            'Sahibabad Industrial Area',
          ],
        ),
        IndianDistrict(
          name: 'Lucknow',
          cities: [
            'Lucknow',
            'Gomti Nagar IT Hub',
            'HCL IT City',
            'Hazratganj',
            'Alambagh',
          ],
        ),
        IndianDistrict(
          name: 'Kanpur Nagar',
          cities: [
            'Kanpur',
            'Civil Lines',
            'IIT Kanpur Area',
            'Panki Industrial Area'
          ],
        ),
        IndianDistrict(
          name: 'Agra',
          cities: ['Agra', 'Sanjay Place'],
        ),
        IndianDistrict(
          name: 'Varanasi',
          cities: ['Varanasi', 'Sigra', 'Lanka', 'Ramnagar Industrial Area'],
        ),
        IndianDistrict(
          name: 'Prayagraj',
          cities: ['Prayagraj', 'Civil Lines', 'Naini Industrial Area'],
        ),
        IndianDistrict(
          name: 'Meerut',
          cities: ['Meerut', 'Partapur Industrial Area', 'Modinagar'],
        ),
        IndianDistrict(
          name: 'Bareilly',
          cities: ['Bareilly', 'Civil Lines'],
        ),
        IndianDistrict(
          name: 'Aligarh',
          cities: ['Aligarh', 'Tala Nagari'],
        ),
        IndianDistrict(
          name: 'Gorakhpur',
          cities: ['Gorakhpur', 'GIDA Industrial Area'],
        ),
      ],
    ),
    IndianState(
      name: 'Madhya Pradesh',
      districts: [
        IndianDistrict(
          name: 'Indore',
          cities: [
            'Indore',
            'Super Corridor IT Park',
            'Crystal IT Park',
            'Vijay Nagar',
            'Palasia',
            'Pithampur Auto & Pharma Hub',
          ],
        ),
        IndianDistrict(
          name: 'Bhopal',
          cities: [
            'Bhopal',
            'MP Nagar',
            'Arera Colony',
            'Mandideep Industrial Area',
          ],
        ),
        IndianDistrict(
          name: 'Gwalior',
          cities: ['Gwalior', 'Malanpur Industrial Area'],
        ),
        IndianDistrict(
          name: 'Jabalpur',
          cities: ['Jabalpur', 'Civil Lines'],
        ),
        IndianDistrict(
          name: 'Ujjain',
          cities: ['Ujjain', 'Dewas Road'],
        ),
      ],
    ),
    IndianState(
      name: 'Odisha',
      districts: [
        IndianDistrict(
          name: 'Khordha',
          cities: [
            'Bhubaneswar',
            'Infocity',
            'Patia IT Corridor',
            'Chandrasekharpur',
            'Saheed Nagar',
          ],
        ),
        IndianDistrict(
          name: 'Cuttack',
          cities: ['Cuttack', 'Choudwar Industrial Area'],
        ),
        IndianDistrict(
          name: 'Sundargarh',
          cities: ['Rourkela', 'Civil Township'],
        ),
        IndianDistrict(
          name: 'Sambalpur',
          cities: ['Sambalpur', 'Burla'],
        ),
        IndianDistrict(
          name: 'Puri',
          cities: ['Puri'],
        ),
      ],
    ),
    IndianState(
      name: 'Assam',
      districts: [
        IndianDistrict(
          name: 'Kamrup Metropolitan',
          cities: [
            'Guwahati',
            'Dispur',
            'GS Road',
            'Paltan Bazaar',
            'IIT Guwahati Area',
          ],
        ),
        IndianDistrict(
          name: 'Dibrugarh',
          cities: ['Dibrugarh'],
        ),
        IndianDistrict(
          name: 'Silchar',
          cities: ['Silchar', 'NIT Silchar Area'],
        ),
        IndianDistrict(
          name: 'Jorhat',
          cities: ['Jorhat'],
        ),
      ],
    ),
    IndianState(
      name: 'Bihar',
      districts: [
        IndianDistrict(
          name: 'Patna',
          cities: [
            'Patna',
            'Boring Road',
            'Bailey Road',
            'Kankarbagh',
            'Danapur',
            'Patliputra Industrial Area',
          ],
        ),
        IndianDistrict(
          name: 'Gaya',
          cities: ['Gaya', 'Bodh Gaya'],
        ),
        IndianDistrict(
          name: 'Muzaffarpur',
          cities: ['Muzaffarpur', 'Bela Industrial Area'],
        ),
        IndianDistrict(
          name: 'Bhagalpur',
          cities: ['Bhagalpur'],
        ),
      ],
    ),
    IndianState(
      name: 'Jharkhand',
      districts: [
        IndianDistrict(
          name: 'Ranchi',
          cities: ['Ranchi', 'Namkum IT Hub', 'Harmu', 'Doranda'],
        ),
        IndianDistrict(
          name: 'East Singhbhum',
          cities: [
            'Jamshedpur',
            'Bistupur',
            'Sakchi',
            'Adityapur Industrial Area'
          ],
        ),
        IndianDistrict(
          name: 'Dhanbad',
          cities: ['Dhanbad', 'IIT ISM Area'],
        ),
        IndianDistrict(
          name: 'Bokaro',
          cities: ['Bokaro Steel City'],
        ),
      ],
    ),
    IndianState(
      name: 'Uttarakhand',
      districts: [
        IndianDistrict(
          name: 'Dehradun',
          cities: [
            'Dehradun',
            'IT Park Sahastradhara Road',
            'Rajpur Road',
            'Rishikesh',
          ],
        ),
        IndianDistrict(
          name: 'Haridwar',
          cities: ['Haridwar', 'SIDCUL Industrial Area', 'Roorkee'],
        ),
        IndianDistrict(
          name: 'Nainital',
          cities: ['Haldwani', 'Nainital'],
        ),
        IndianDistrict(
          name: 'Udham Singh Nagar',
          cities: ['Rudrapur SIDCUL', 'Pantnagar', 'Kashipur'],
        ),
      ],
    ),
    IndianState(
      name: 'Himachal Pradesh',
      districts: [
        IndianDistrict(
          name: 'Solan',
          cities: ['Baddi Industrial Belt', 'Solan', 'Barotiwala', 'Nalagarh'],
        ),
        IndianDistrict(
          name: 'Shimla',
          cities: ['Shimla', 'Shoghi'],
        ),
        IndianDistrict(
          name: 'Kangra',
          cities: ['Dharamshala', 'Kangra', 'Palampur'],
        ),
      ],
    ),
    IndianState(
      name: 'Goa',
      districts: [
        IndianDistrict(
          name: 'North Goa',
          cities: ['Panaji', 'Mapusa', 'Porvorim', 'Pilerne Industrial Estate'],
        ),
        IndianDistrict(
          name: 'South Goa',
          cities: ['Margao', 'Vasco da Gama', 'Verna Industrial Estate'],
        ),
      ],
    ),
    IndianState(
      name: 'Chandigarh',
      districts: [
        IndianDistrict(
          name: 'Chandigarh',
          cities: [
            'Chandigarh',
            'IT Park Chandigarh',
            'Sector 17',
            'Sector 34'
          ],
        ),
      ],
    ),
    IndianState(
      name: 'Jammu & Kashmir',
      districts: [
        IndianDistrict(
          name: 'Srinagar',
          cities: ['Srinagar', 'Rangreth IT Park'],
        ),
        IndianDistrict(
          name: 'Jammu',
          cities: ['Jammu', 'Bari Brahmana Industrial Area'],
        ),
      ],
    ),
    IndianState(
      name: 'Puducherry',
      districts: [
        IndianDistrict(
          name: 'Puducherry',
          cities: ['Puducherry', 'Oulgaret', 'Sedharapet'],
        ),
      ],
    ),
    IndianState(
      name: 'Chhattisgarh',
      districts: [
        IndianDistrict(
          name: 'Raipur',
          cities: [
            'Raipur',
            'Nava Raipur (Atal Nagar)',
            'Urla Industrial Area'
          ],
        ),
        IndianDistrict(
          name: 'Durg',
          cities: ['Bhilai', 'Durg'],
        ),
        IndianDistrict(
          name: 'Bilaspur',
          cities: ['Bilaspur', 'Sirgitti'],
        ),
      ],
    ),
    IndianState(
      name: 'Other States & UTs',
      districts: [
        IndianDistrict(
          name: 'Tripura',
          cities: ['Agartala', 'Bodhjungnagar IT Park'],
        ),
        IndianDistrict(
          name: 'Meghalaya',
          cities: ['Shillong', 'New Shillong Tech Park'],
        ),
        IndianDistrict(
          name: 'Manipur',
          cities: ['Imphal', 'Mantripukhri IT SEZ'],
        ),
        IndianDistrict(
          name: 'Nagaland',
          cities: ['Dimapur', 'Kohima'],
        ),
        IndianDistrict(
          name: 'Mizoram',
          cities: ['Aizawl'],
        ),
        IndianDistrict(
          name: 'Sikkim',
          cities: ['Gangtok'],
        ),
        IndianDistrict(
          name: 'Arunachal Pradesh',
          cities: ['Itanagar', 'Naharlagun'],
        ),
        IndianDistrict(
          name: 'Ladakh',
          cities: ['Leh', 'Kargil'],
        ),
      ],
    ),
  ];

  /// Universal search across State, District, and City names.
  static List<LocationSearchResult> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final results = <LocationSearchResult>[];
    final seen = <String>{};

    for (final state in states) {
      // 1. Check state match
      if (state.name.toLowerCase().contains(q)) {
        final key = 'state:${state.name}';
        if (seen.add(key)) {
          results.add(LocationSearchResult(
            title: state.name,
            subtitle: '${state.districts.length} districts in ${state.name}',
            formattedLocation: '${state.name}, India',
            type: 'state',
          ));
        }
      }

      for (final district in state.districts) {
        // 2. Check district match
        if (district.name.toLowerCase().contains(q)) {
          final key = 'district:${district.name}:${state.name}';
          if (seen.add(key)) {
            results.add(LocationSearchResult(
              title: district.name,
              subtitle: '${state.name} · ${district.cities.length} cities',
              formattedLocation: '${district.name}, ${state.name}',
              type: 'district',
            ));
          }
        }

        // 3. Check city match
        for (final city in district.cities) {
          if (city.toLowerCase().contains(q)) {
            final key = 'city:$city:${district.name}:${state.name}';
            if (seen.add(key)) {
              results.add(LocationSearchResult(
                title: city,
                subtitle: '${district.name}, ${state.name}',
                formattedLocation: '$city, ${state.name}',
                type: 'city',
              ));
            }
          }
        }
      }
    }

    return results;
  }
}
