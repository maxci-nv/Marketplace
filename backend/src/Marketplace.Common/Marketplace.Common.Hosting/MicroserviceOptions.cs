namespace Marketplace.Common.Hosting
{
    /// <summary>
    /// Конфигурация микросервиса
    /// </summary>
    internal class MicroserviceOptions
    {
        /// <summary>
        /// Название микросервиса
        /// </summary>
        public required string Name { get; set; }

        /// <summary>
        /// Ипользуется Swagger
        /// </summary>
        public bool UseSwagger { get; set; }

    }
}
