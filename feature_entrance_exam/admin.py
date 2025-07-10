from django.contrib import admin
from django.utils.html import format_html
from .models import (
    Degree, Program, Minor, MultiDisciplinaryCourse, ValueAddedCourse,
    AbilityEnhancementCourse, AddOnCourse, Major, CourseApplication
)


@admin.register(Degree)
class DegreeAdmin(admin.ModelAdmin):
    list_display = ('name', 'code')
    search_fields = ('name', 'code')
    ordering = ('name',)


@admin.register(Program)
class ProgramAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'degree', 'entrance_application_fee', 'pre_req_stream')
    list_filter = ('degree', 'pre_req_stream')
    search_fields = ('name', 'code')
    ordering = ('code', 'name')
    list_editable = ('entrance_application_fee',)


class MinorInline(admin.TabularInline):
    model = Major.available_minors.through
    extra = 1
    verbose_name = "Available Minor"
    verbose_name_plural = "Available Minors"


class MultiDisciplinaryCourseInline(admin.TabularInline):
    model = Major.available_mdc.through
    extra = 1
    verbose_name = "Available MDC"
    verbose_name_plural = "Available MDCs"


@admin.register(Major)
class MajorAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'program', 'prereq_stream', 'major_course_fee', 
                   'actual_available_seats', 'buffer_seats', 'total_seats', 
                   'entrance_exam_DateTime')
    list_filter = ('program', 'prereq_stream', 'entrance_exam_DateTime')
    search_fields = ('name', 'code', 'program__name')
    ordering = ('code', 'name')
    list_editable = ('major_course_fee', 'actual_available_seats', 'buffer_seats')
    filter_horizontal = ('available_minors', 'available_mdc')
    date_hierarchy = 'entrance_exam_DateTime'
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('name', 'code', 'program', 'prereq_stream')
        }),
        ('Course Details', {
            'fields': ('major_course_fee', 'entrance_exam_DateTime')
        }),
        ('Seat Management', {
            'fields': ('actual_available_seats', 'buffer_seats', 'total_seats')
        }),
        ('Available Courses', {
            'fields': ('available_minors', 'available_mdc'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ('total_seats',)


@admin.register(Minor)
class MinorAdmin(admin.ModelAdmin):
    list_display = ('name', 'code')
    search_fields = ('name', 'code')
    ordering = ('code', 'name')


@admin.register(MultiDisciplinaryCourse)
class MultiDisciplinaryCourseAdmin(admin.ModelAdmin):
    list_display = ('name', 'code')
    search_fields = ('name', 'code')
    ordering = ('code', 'name')


@admin.register(ValueAddedCourse)
class ValueAddedCourseAdmin(admin.ModelAdmin):
    list_display = ('name', 'code')
    search_fields = ('name', 'code')
    ordering = ('code', 'name')


@admin.register(AbilityEnhancementCourse)
class AbilityEnhancementCourseAdmin(admin.ModelAdmin):
    list_display = ('name', 'code')
    search_fields = ('name', 'code')
    ordering = ('code', 'name')


@admin.register(AddOnCourse)
class AddOnCourseAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'aoc_course_fee')
    search_fields = ('name', 'code')
    ordering = ('code', 'name')
    list_editable = ('aoc_course_fee',)


@admin.register(CourseApplication)
class CourseApplicationAdmin(admin.ModelAdmin):
    list_display = ('user', 'degree', 'program', 'major', 'fee_amount', 
                   'is_fee_paid', 'get_course_type')
    list_filter = ('is_fee_paid', 'degree', 'program', 'major')
    search_fields = ('user__email', 'user__first_name', 'user__last_name', 
                    'major__name', 'program__name')
    ordering = ('-id',)
    list_editable = ('is_fee_paid',)
    readonly_fields = ('fee_amount',)
    
    fieldsets = (
        ('User Information', {
            'fields': ('user',)
        }),
        ('Academic Details', {
            'fields': ('degree', 'program', 'major')
        }),
        ('Course Selections', {
            'fields': ('minor', 'mdc', 'vac', 'aec', 'aoc'),
            'classes': ('collapse',)
        }),
        ('Payment Information', {
            'fields': ('fee_amount', 'is_fee_paid')
        }),
    )
    
    def get_course_type(self, obj):
        """Display which type of course is selected"""
        if obj.major:
            return f"Major: {obj.major.name}"
        elif obj.minor:
            return f"Minor: {obj.minor.name}"
        elif obj.mdc:
            return f"MDC: {obj.mdc.name}"
        elif obj.vac:
            return f"VAC: {obj.vac.name}"
        elif obj.aec:
            return f"AEC: {obj.aec.name}"
        elif obj.aoc:
            return f"AOC: {obj.aoc.name}"
        else:
            return "No course selected"
    
    get_course_type.short_description = "Course Type"
    
    def get_queryset(self, request):
        """Optimize queryset with select_related for better performance"""
        return super().get_queryset(request).select_related(
            'user', 'degree', 'program', 'major', 'minor', 'mdc', 'vac', 'aec', 'aoc'
        )


# Customize admin site
admin.site.site_header = "PWC Entrance Exam Administration"
admin.site.site_title = "PWC Admin Portal"
admin.site.index_title = "Welcome to PWC Entrance Exam Portal"
