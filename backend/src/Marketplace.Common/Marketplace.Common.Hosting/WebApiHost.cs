using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Marketplace.Common.Hosting
{
    public static class WebApiHost
    {
        /// <summary>
        /// Запускает микросервис с WebApi
        /// </summary>
        public static void Run(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            var microserviceOptions = builder.Configuration
                .GetSection("Microservice")
                .Get<MicroserviceOptions>();

            if (microserviceOptions == null)
                throw new ApplicationException("Отсутвует конфигурация Microservice в appsettings.json.");

            builder.Services.AddControllers();

            if (microserviceOptions.UseSwagger == true)
            {
                builder.Services.AddEndpointsApiExplorer();
                builder.Services.AddSwaggerGen();
            }

            var app = builder.Build();

            if (microserviceOptions.UseSwagger == true)
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseHttpsRedirection();
            app.UseAuthorization();

            app.MapControllers();

            app.Run();
        }
    }
}
