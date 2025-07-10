from django.urls import path
from core_users.api_views import (StartRegistrationAPIView, VerifyOTPAPIView, ResendOTPAPIView, SetPasswordAPIView,
                                  LoginAPIView, CustomUserAPIView, UserApplicationAPIView, UserEducationDetailsAPIView)

urlpatterns = [
    path('register/', StartRegistrationAPIView.as_view(), name='start-registration'),
    path('verify-otp/', VerifyOTPAPIView.as_view(), name='verify-otp'),
    path('resend-otp/', ResendOTPAPIView.as_view(), name='resend-otp'),
    path('set-password/', SetPasswordAPIView.as_view(), name='set-password'),
    path('login/', LoginAPIView.as_view(), name='login'),
    path('me/', CustomUserAPIView.as_view(), name='me'),

    path('user-application/', UserApplicationAPIView.as_view(), name='user-application'),
    path('user-education-details/', UserEducationDetailsAPIView.as_view(), name='user-education-detail'),
]