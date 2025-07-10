from django.urls import path
from feature_entrance_exam.views import CourseApplicationAPIView
urlpatterns = [
    path('course-application/', CourseApplicationAPIView.as_view(), name='course-application'),
]