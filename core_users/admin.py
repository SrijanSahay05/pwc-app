from django.contrib import admin
from core_users.authentication_models import RegistrationSession, CustomUser
from core_users.models import UserApplication, EducationDetailsModel
# Register your models here.
admin.site.register(RegistrationSession)
admin.site.register(CustomUser)

admin.site.register(UserApplication)
admin.site.register(EducationDetailsModel)