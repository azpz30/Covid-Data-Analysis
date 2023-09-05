-- Take a peek at the imported excel files into database as check if everything is as expected
select *
from CovidAnalysis.dbo.CovidDeaths
order by 3,4

select *
from CovidAnalysis.dbo.CovidVax
order by 3,4

-- Get a temp table with the data that is important for now
-- select Location, date, total_cases, new_cases, total_deaths, population
-- Convert null values from the column into 0, and change the type varchar to float across the whole column
With NumericConversion as (
	Select
		Location,
		continent,
		date,
		new_cases,
		new_deaths,
		population,
		Case when ISNUMERIC(total_cases) = 1 then CAST(total_cases As float) Else 0 End as numeric_cases,
		Case when ISNUMERIC(total_deaths) = 1 then CAST(total_deaths As float) Else 0 End as numeric_deaths
	From
		CovidAnalysis.dbo.CovidDeaths
)
-- now select the converted type values from the temp table and perform calculation
-- fatality_percentage = our chances of dying if we contract covid-19
Select *
Into #TempNum
From NumericConversion;

-- Looking at the total_cases vs total_deaths to calculate fatality_percentage
Select 
	Location,
	date,
	numeric_cases,
	numeric_deaths,
	population,
	(numeric_cases/population)*100 as death_percentage,
	Case
		when numeric_cases <> 0 and numeric_deaths <> 0  then 
		-- change to %
			(numeric_deaths/numeric_cases)*100
		else 
			0
	End as fatality_percentage
From 
	#TempNum
where continent is not null
-- uncommenting this next line will help us get the fatality ratio of our country
-- where location like '%Bangladesh%'
order by location, date;

-- Highest Infection Rate were we calculate percentage of population infected for each country.
Select Location, population, MAX(numeric_cases) as infection_count, MAX(numeric_cases/population)*100 as population_infected
From #TempNum
where continent is not null
Group by Location, population
order by population_infected desc

-- Highest Death Count for each location. here we sum up all the death on each day by using MAX function for each locatoion.
Select Location, MAX(numeric_deaths) as death_count
From #TempNum
where continent is not null
Group by Location
order by death_count desc

-- Death count by continent
Select continent, MAX(numeric_deaths) as death_count
From #TempNum
where continent is not null
Group by continent
order by death_count desc

-- Death count each day across the whole world
Select date, SUM(new_cases) as 'cases/day', SUM(cast(new_deaths as int)) as 'deaths/day', 
		(SUM(cast(new_deaths as int))/SUM(new_cases))*100 as 'deathPercent/day'
From #TempNum
where continent is not null
Group by date

DROP TABLE #TempNum;


-- Total Population vs Total Vaccination
-- Lets join the two main tables -> CovidDeaths and CovidVax
Select death.continent, death.location, death.date, death.population, vax.new_vaccinations,
	SUM(cast(vax.new_vaccinations as bigint)) OVER (Partition by death.location order by death.location, death.date) as cumulative_vax
From CovidAnalysis.dbo.CovidDeaths death
Join CovidAnalysis.dbo.CovidVax	   vax
	On death.location = vax.location
	and death.date = vax.date 
where death.continent is not null
Order by 2,3

-- Use CTE
With PopulationvsVax (continent, location, date, population, new_vaccinations, cumulative_vax)
as
(
Select death.continent, death.location, death.date, death.population, vax.new_vaccinations,
	SUM(cast(vax.new_vaccinations as bigint)) OVER (Partition by death.location order by death.location, death.date) as cumulative_vax
From CovidAnalysis.dbo.CovidDeaths death
Join CovidAnalysis.dbo.CovidVax	   vax
	On death.location = vax.location
	and death.date = vax.date 
where death.continent is not null
--Order by 2,3
)
Select * , (cumulative_vax/population)*100 as 'cumulativeVax/population'
From PopulationvsVax

-- Store important tables here to visualization later on
-- Each table contains data is the name of the view suggests.
Create View PercentPopulationVaxed as 
Select death.continent, death.location, death.date, death.population, vax.new_vaccinations,
	SUM(cast(vax.new_vaccinations as bigint)) OVER (Partition by death.location order by death.location, death.date) as cumulative_vax
From CovidAnalysis.dbo.CovidDeaths death
Join CovidAnalysis.dbo.CovidVax	   vax
	On death.location = vax.location
	and death.date = vax.date 
where death.continent is not null

Create View DeathPercent as
Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From CovidAnalysis.dbo.CovidDeaths
--Where location like '%states%'
where continent is not null 
--Group By date

Create View ContinentDeathCount as
Select location, SUM(cast(new_deaths as int)) as TotalDeathCount
From CovidAnalysis.dbo.CovidDeaths
--Where location like '%states%'
Where continent is null 
and location not in ('World', 'European Union', 'International')
Group by location

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From CovidAnalysis.dbo.CovidDeaths
--Where location like '%states%'
where continent is not null 
--Group By date
order by 1,2

Create View InfectionDataCountryWise as
Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From CovidAnalysis.dbo.CovidDeaths
--Where location like '%states%'
Group by Location, Population

Create View InfectionDataDateWise as 
Select Location, Population,date, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From CovidAnalysis.dbo.CovidDeaths
--Where location like '%states%'
Group by Location, Population, date
order by PercentPopulationInfected desc
