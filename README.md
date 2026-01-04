# VitaMate – Smart Health & Lifestyle Assistant

VitaMate is a smart mobile health and lifestyle tracking application developed as a Junior Project for the Faculty of Software Engineering at Syrian Private University.

The application helps users adopt and maintain a healthy lifestyle by tracking daily habits such as nutrition, water intake, physical activity, sleep, and unhealthy habits, while providing reminders, reports, and a motivational reward system.

---

## Academic Information
- **University**: Syrian Private University
- **Faculty**: Software Engineering
- **Academic Year**: 2025 – 2026
- **Project Type**: Junior Project

### Team Members
- Salam Mohammed Al-Ayash
- Amenah Ayman Zaitoun

### Supervisor
- Eng. Raghad Al-Hossny

---

## Project Objectives
- Track daily nutrition and caloric intake
- Monitor water consumption and hydration levels
- Track physical activity and workouts
- Monitor sleep duration and quality
- Assist users in breaking unhealthy habits
- Provide weekly and monthly health reports
- Encourage healthy behavior using a points-based reward system

---

## System Scope
- Secure user authentication and profile management
- Health tracking (nutrition, water, activity, sleep, habits)
- Notifications and reminders
- Reports and analytics dashboards
- PostgreSQL database for persistent storage
- RESTful API backend

---

## Technology Stack

### Backend
- Django
- Django REST Framework
- PostgreSQL
- JWT Authentication

### Frontend
- Flutter (Android & iOS)

### Tools
- Git & GitHub
- Visual Studio Code
- Postman

---

## Project Structure
vitamate/
|_docs/VitaMate Report.docx
|_README.md
|_.gitignore
|_implementation/
                |_Vitamate_backend/
                |_vitamate_frontend/

---

## Running the Backend (Django)

### 1) Go to backend directory
```bash
cd implementation/Vitamate_backend
2) Create virtual environment

Windows:

python -m venv venv


Mac/Linux:

python3 -m venv venv

3) Activate virtual environment

Windows:

venv\Scripts\activate


Mac/Linux:

source venv/bin/activate

4) Install dependencies
pip install -r requirements.txt

5) Apply database migrations
python manage.py migrate

6) Run the development server
python manage.py runserver


The backend server will start at:

http://127.0.0.1:8000/

## Running the Frontend (Flutter)

1) Go to frontend directory
cd implementation/vitamate_frontend

2) Install Flutter packages
flutter pub get

3) Run the application
flutter run